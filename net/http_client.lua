local M={}

local dbg= package.loaded.debugger or function() end
local timeout= 6* 10^6 -- Seconds

if not net and not net.tick then
  error "This module require picotcp"
end

 
local request_tmpl=table.concat(
  {
    "GET /{path} HTTP/1.1",
    "Host: {host}",
    "Cache-Control: max-age=0",
    "Upgrade-Insecure-Requests: 0",
    "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36",
    "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
    "Accept-Language: en-US,en;q=0.8,de;q=0.6",
    "",
    ""
  }, "\r\n")


function M.sanitize_url(url)

  if url:match("[%s%c]") then
     error "url contains spaces or ctrl chars"
  end 
  local proto,tail=url:match('^(%a+)://(.+)')
  if not proto then
    tail=url
    proto="http"
  end   

  local host,colon,port, path_sep,path=tail:match('(^[%a%d-.]+)(:?)(%d*)(/?)([%w%p%?]*)')
  if colon==":" and #port==0 then
    error "url format: colon without port number"
  end
  if #path>0 and  #path_sep==0 then
    error "url format: missing /"
  end
  if not host then 
    error "url format: no host"
  end    
  
  print(string.format("Host=%s Path=%s Port=%s",host,path or "",port or ""))

  return {
     proto=proto, 
     host=host,
     port=port or "",
     path=path or "" 
  }

end   


local function build_request(u)
  local portsuffix

  if tonumber(u.port) then
    portsuffix=":"..u.port
  else
    portsuffix=""
  end

  return  string.gsub(request_tmpl,"{(%w+)}",{host=u.host..portsuffix,path=u.path})   
    
end     

local function get_headers(resp)
  local headers={}
  local resp_code,resp_text
  local complete=false 
  local start,stop=1,1
  local bodyindex=0

  start,stop=resp:find("%C*\r?\n",start)
    
  while start and stop do
  
    local l=resp:sub(start,stop):match("%C*")
    print(l)
    if l=="" then
      print("header complete")
      complete=true
      bodyindex=stop+1 
      break
    end
    if not resp_code then
      local c,t = l:match("HTTP/%d.%d%s*(%d%d%d)(.*)")
      if c then 
          resp_code,resp_text=c,t
       end
    else 
      local k,v = l:match("([-%a%d]+):%s*(.*)")
      if k~=nil then
        headers[k:lower()]=v
      end
    end
    start,stop=resp:find("%C*\r?\n",stop+1)
  end
  
  return headers,{code=resp_code,text=resp_text},complete,bodyindex 
end


local function stream_process(chunk,finish)
  local s =""
  local headers, response_code, body, headers_complete      
  local data={}
  local ctype
  local bodyindex
  local total_length
  local length=0 

 
  repeat 
    data[#data+1]=chunk
    length=length+#chunk 
    -- As long headers are not complete concatenate chunks and parse them 
    if not headers_complete then 
      s = s .. chunk 
      headers,response_code,headers_complete,bodyindex=get_headers(s)
      if headers_complete then 
        ctype=headers["content-type"]
        if ctype then 
         ctype=ctype:match("%a+/%a+") or ""
        else
         ctype=""
        end 
        pcall( function() 
                 total_length= headers["content-length"]+bodyindex-1
                 print("total: ",total_length)
                end )          

      end   
    end
    if total_length then
      finish= length>=total_length
      if finish then dbg() end   
    elseif ctype=="text/html" then
      finish=chunk:find("</[Hh][Tt][Mm][Ll]>")
    end     
    if finish then 
      return headers,response_code, table.concat(data),finish
    else 
      chunk,finish=coroutine.yield()
    end
  until false         
end 


local function receive(s,req)
  local req_sent=false
  local res={}
  local finish=false
  local err=net.ERR_OK
  local tstart=tmr.read() -- start if timeout measuerment period
    -- Variables for statistics display
  local total=0
  local t0 = tstart
  local timefactor = 10^6 / 1024
  local modcnt = 0

   
   local case = {}
    
    function case.write()
       if not req_sent then
         local b=build_request(req)
         print(b)
         s:send(b)
         req_sent=true
       end
    end
    
    function case.read()
      local r 

      tstart=tmr.read() -- restart timeout
     
      --repeat
        r,err = s:recv(32768)
       
        if err~=net.ERR_OK then
          finish=true
          return
        end 
       
        if  #r>0 then  
          total = total + #r  
          res[#res+1]=r
        end   
      --until #r==0 
    end 

    function case.close() finish=true end
    function case.fin() finish=true end

  s:callback(function(event)
    
    local f=case[event] 
    if f then f() end     
  end)

  local t=tmr.read()
  local stream_thread=coroutine.create(stream_process)
  local dtime=tmr.read() -- Dispatch time

  -- Main loop
  while not finish do    
    net.tick()
    if tmr.getdiffnow(nil,tstart)>timeout then
      err=net.ERR_WAIT_TIMEDOUT
      finish=true
    end
    if (#res>0 and tmr.getdiffnow(nil,dtime)>100000) or finish then 
      local success,headers,response_code,content,_fin=coroutine.resume(stream_thread,table.concat(res),finish)
      if not success then 
        error(headers)
      else 
        if _fin then 
          return {
            headers=headers,
            response_code=response_code,
            content=content  
          }   
        end   
      end
      res={}
    end       
  end

end     


function M.request(url)

   local u=M.sanitize_url(url)
   local hostip

   if not pcall(function() hostip=net.packip(u.host) end) then
     hostip=net.lookup(u.host)
   end
   
   if hostip==0 then
    error(string.format("Host %s is neither an IP address nor can resolved",host))
   end

   local s=net.socket(0)
   s:setoption(net.OPT_RCVBUF,32768)
   if s:connect(hostip,tonumber(u.port) or 80)~=net.ERR_OK then
      error(string.format("Cannot connect to host %s port %s",u.host,u.port))
   end 

   return receive(s,u) 

end   

return M