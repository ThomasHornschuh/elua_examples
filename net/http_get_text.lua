
require("util")
dbg=require("debugger")

local nobreak=true



--Connection: keep-alive

local request_tmpl=[[GET /{path} HTTP/1.1
Host: {host}
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 0
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8
Accept-Language: en-US,en;q=0.8,de;q=0.6

]]



function get_headers(resp)
local headers={}

local headertext=string.match(resp,"^(.-)<!DOCTYPE")

  if not headertext then
    headertext=string.match(resp,"^(.-)<[Hh][Tt][Mm][Ll]>")
  end
  if not headertext then
    headertext=resp
  end

  local resp_code,resp_text=string.match(headertext,"HTTP/%d.%d%s*(%d%d%d)(%C*)")

  for k,v in string.gmatch(headertext,"([-%a%d]+):%s*(%C*)") do
    if k~=nil then
      headers[k]=v
    end
  end
  return headers,{code=resp_code,text=resp_text}
end


function get_body(resp)

  return string.match(resp,"<[Hh][Tt][Mm][Ll].->.*</[Hh][Tt][Mm][Ll]>")

end


function get_length(s)
local t=type(s)

  if t=="string" or t=="table" then
    return #s
  else
    return 0
  end
end

local tag_pattern="</?(%a+.-)/?>"

function count_tags(content)
local count=0

  for t in content:gmatch(tag_pattern) do
    count=count+1
  end
  return count
end


function more(content,pagesize)

local temp,l,n

  pagesize=pagesize or 25

  temp=content:gsub(tag_pattern,"")
  local known={}
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

  local lines={}
  for l in temp:gmatch("(%C*)\n\r?") do
    lines[#lines+1]=l
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

function main()

local timeout=10*10^6
local body

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

    local hostip=net.lookup(host)


    local s=net.socket(0)
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
      net.send(s,request)
      while string.find(res,"</[Hh][Tt][Mm][Ll]>")==nil do
        local t1=tmr.read()
        res,err=net.recv(s,500*511,nil,timeout)
        t1=tmr.getdiffnow(nil,t1)
        net_time=net_time+t1
        print(string.format("Err=%d, Bytes=%d, Time=%.3f ms",err,get_length(res),t1/1000))

        if res and #res>0 then
          response=response..res
        end
        if err~=net.ERR_OK  then
          break
        end
      end
      net.close(s)
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
        body=get_body(response)
        print(string.format("Body size %d bytes",get_length(body)))
        if body then
          t1=tmr.read()
          print(string.format("Number of tags in Body: %d, counted in %.3f ms",count_tags(body),tmr.getdiffnow(nil,t1)/1000))
        end
      end
      print(string.format("Read %d bytes, response time is  %.3f ms",#response,timer))
      print(string.format("Transfer time %.3f ms",net_time/1000))
      io.write("Print content (Y/N)?")
      local qry=io.read("*l")
      if qry=="Y" or qry=="y" then
        more(body)
        print()
      end
    else
      net.close(s)
      print("Connection failure");
    end
  until false
end

dbg.call(main)
