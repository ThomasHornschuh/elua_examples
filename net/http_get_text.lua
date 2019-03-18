
require("util")
local dbg= package.loaded.debugger or function() end

local nobreak=true
local picotcp = net.tick
local timeout= 6* 10^6 -- Seconds
local async=picotcp 



local request_tmpl_t = {
  "GET /{path} HTTP/1.1",
  "Host: {host}",
  "Cache-Control: max-age=0",
  "Upgrade-Insecure-Requests: 0",
  "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36",
  "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
  "Accept-Language: en-US,en;q=0.8,de;q=0.6",
  "",
  ""
}

local request_tmpl=table.concat(request_tmpl_t,"\r\n")


local function get_headers(resp)
  local headers={}
  local resp_code,resp_text
  
   for l in resp:gmatch("(%C*)\r?\n") do

     if l=="" then
       print("header complete")
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
   end

   --local resp_code,resp_text=resp:match("HTTP/%d.%d%s*(%d%d%d)(%C*)")

  return headers,{code=resp_code,text=resp_text}
end


local function get_body(resp, headers)
  local ctype=headers["content-type"]
  if ctype then 
    ctype=ctype:match("%a+/%a+") or ""
  else
    ctype=""
  end 

  -- Header Section ends with an empty line terminated by cr/lf, content is everything behind
  local content=resp:match("\r?\n\r?\n(.*)")

  if ctype=="text/html" then
    return content:match("<[Hh][Tt][Mm][Ll].->.*</[Hh][Tt][Mm][Ll]>") or content ,ctype
  else 
    return content,ctype
  end  
end


local function get_length(s)
local t=type(s)

  if t=="string" or t=="table" then
    return #s
  else
    return 0
  end
end

local tag_pattern="</?(%a+.-)/?>"

local function count_tags(content)
local count=0

  for t in content:gmatch(tag_pattern) do
    count=count+1
  end
  return count
end


local function more(content, ctype, pagesize)

local temp,l,n

  pagesize=pagesize or 25
  dbg()

  if ctype=="text/html" then
    -- remove scripts
    local sBytes=0
    temp=content:gsub('(<script)(.-)(</script>)',
                 function(t1,script,t2) 
                   dbg()
                   sBytes=sBytes+#script
                   return ""
                 end)

    print(string.format("%d Bytes of Script code removed",sBytes))
 
    -- remove tags
    temp=temp:gsub(tag_pattern,"")

    -- transform special chars
    --local known={}
    temp=temp:gsub("&(%l+);",function(s)
     --Debug code....
     --if not known[s] then
       --dbg()
       --known[s]=true
     --end
      if s=="nbspc" then
        return " "
      elseif s=="ndash" then
        return "-- "
      elseif s=="middot" then
        return "* "
      elseif s=="gt" then
        return ">"
      elseif s=="le" then
        return "<="
      elseif s=="lt" then
        return "<"
      else
        return ""
      end
    end )
  else 
    temp=content.."\n" -- add lf to last line for pattern matching below
  end 

  local lines={}

  for l in temp:gmatch("(%C*)\r?\n") do
    -- Split line into substrings of max 80 characters
    while #l > 80 do
      lines[#lines+1]= l:sub(1,80)
      l= l:sub(81,#l)
    end
    if #l > 0 then
      lines[#lines+1]=l
    end
  end
  n=1
  print(string.format("Memory usage %.0f KB",collectgarbage('count')))
  repeat
    for i=0,pagesize-1 do
      if lines[n+i] then
        print(lines[n+i])
      end
    end

    local c=uart.getchar(0)
    if (c=="b" or c=="B") and n>pagesize then
      n=n-pagesize
    else
      n=n+pagesize
    end
  until c=="q" or c=="Q"
end


local function recv(s,request)
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

  local function callback(event)

     if event=="connect" then
       print("Connected")
     end
     if event=="write" and not req_sent then
       s:send(request)
       print("request sent")
       req_sent=true
     end       
     if event=="read" and not finish then
       local r
       tstart=tmr.read() -- restart timeout
             
       repeat
         r,err = s:recv(32768)
         if err~=net.ERR_OK then
           finish=true
           return
         end 
         total = total + #r
         if (modcnt % 10) == 0 then
           term.print(string.format("Received: %d Bytes %d KB/sec \r",total,
                      total / tmr.getdiffnow(nil,t0) * timefactor ))
         end
         modcnt = modcnt + 1 
         if  #r>0 then  
           res[#res+1]=r
           --finish= r:find("</[Hh][Tt][Mm][Ll]>")
           if finish then
            print("\n</html> tag found")
           end
         end
       until #r==0 or finish 
 
     elseif event=="close" or event=="fin" then
       finish=true
     end       
  end 

  s:callback(callback)
  local t=tmr.read()
  while not finish do    
    net.tick()
    if tmr.getdiffnow(nil,tstart)>timeout then
      err=net.ERR_WAIT_TIMEDOUT
      finish=true
    end
  end
  print() -- New line 
  dbg()
  return table.concat(res),err,tmr.getdiffnow(nil,t)
end




local function main()

local body,bodytype,hostip

  repeat
    io.write("\nEnter URL without 'http(s)://' (leave blank to terminate): ")
    local url=io.read("*l")
     if url=="" then
      return
    end
    local host,port,path=string.match(url,"([%a%d-.]+):?(%d*)/?(.*)")
    if not path then
      path=""
    end
    print(string.format("Host=%s Path=%s Port=%s",host,path,port or ""))

    if not pcall(function() hostip=net.packip(host) end) then
      hostip=net.lookup(host)
    end

    if hostip==0 then
      print(string.format("Host %s is neither an IP address nor can resolved",host))
    end

    local s=net.socket(0)
    if type(s)=="userdata" and s.setoption then
      s:setoption(net.OPT_RCVBUF,32768)
      print("Set receive buf to: ",s:getoption(net.OPT_RCVBUF))
    end    
    local timer=tmr.read()
    local net_time=0
    dbg(nobreak)
    if hostip~=0 and net.connect(s,hostip,tonumber(port) or 80)==net.ERR_OK then
      local response,res,err="",""
      local portsuffix
      if tonumber(port) then
        portsuffix=":"..port
      else
        portsuffix=""
      end

      local request=string.gsub(request_tmpl,"{(%w+)}",{host=host..portsuffix,path=path})
      print(request)
      if async then
        response,err,net_time=recv(s,request)
      else 
        net.send(s,request)
        local res_t={}
        while string.find(res,"</[Hh][Tt][Mm][Ll]>")==nil do
          local t1=tmr.read()
          res,err=net.recv(s,500*511,nil,timeout)
          t1=tmr.getdiffnow(nil,t1)
          net_time=net_time+t1
          print(string.format("Err=%d, Bytes=%d, Time=%.3f ms",err,get_length(res),t1/1000))

          if res and #res>0 then
            res_t[#res_t+1]=res
          end
          if err~=net.ERR_OK  then
            break
          end
        end
        response=table.concat(res_t)
      end 
      pcall( function() net.close(s) end)
  
      timer=tmr.getdiffnow(nil,timer)/1000
      --io.write(response)
      if #response>0 then
        dbg(nobreak)
        local headertime=tmr.read()
        local headers,resp_code=get_headers(response)
        headertime=tmr.getdiffnow(nil,headertime)/1000
        print(string.format("HTTP Response Code: %s %s",tostring(resp_code.code),tostring(resp_code.text)))
        _.pt(headers)
        print(string.format("Header parsing time: %.3f ms",headertime))
        body,bodytype=get_body(response,headers)
        print(string.format("Body type %s size %d bytes",bodytype, get_length(body)))
        if body and bodytype=="text/html" then
          t1=tmr.read()
          print(string.format("Number of tags in Body: %d, counted in %.3f ms",count_tags(body),tmr.getdiffnow(nil,t1)/1000))
        end
      end
      print(string.format("Read %d bytes, response time is  %.3f ms",#response,timer))
      print(string.format("Transfer time %.3f ms",net_time/1000))
      if body and  #body>0 and bodytype and bodytype:match("%a+")=="text" then
        io.write("Print content (Y/N)?")
        local qry=io.read("*l")
        if qry=="Y" or qry=="y" then
          dbg()  
          more(body,bodytype)
          print()
        end
      end 
    else
      net.close(s)
      print("Connection failure");
    end
  until false
end

if picotcp then
-- set time interrupt

  local interval=100000

  cpu.set_int_handler(cpu.INT_TMR_MATCH,
     function() 
      net.tick()
      tmr.set_match_int(tmr.VIRT0,interval,tmr.INT_ONESHOT) 
     end)
  tmr.set_match_int(tmr.VIRT0,100000,tmr.INT_ONESHOT)
end


if type(dbg)=="table" and  dbg.call then
  dbg.call(main)
else
  main()
end

-- Switch off timer interrupt
tmr.set_match_int(tmr.VIRT0,0,tmr.INT_ONESHOT)

