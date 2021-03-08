dbg=require "debugger"

rt=require "runtime"

local maxopen= tonumber(arg[1]) or 3 -- max number of open queries 
print("maxopen=",maxopen)

local g_names= { "bonfirecpu.eu", "github.com", "spiegel.de", 
               "google.com", "lua.org", "microsoft.com", "ricv.org",
               "facebook.com", "twitter.com","ortec.com"
             }

local function testdns_sync(names)
local result={}

  for _,v in pairs(names) do
   local ips=net.unpackip(net.lookup(v),"*s")
   print(string.format("Resolving %s to %s",v, ips))
   result[v]=ips   
  end
  return result
end


local function testdns_async(names)
local result={}

-- async test
local count=0

   local function qryloop() 
     local open=0

     for _,v in pairs(names) do

       while open >= maxopen do
          coroutine.yield()
       end
       print("Query: ",v)
       net.lookup(v,function(ip)
                  count=count + 1
                  open=open - 1
                  local ips=net.unpackip(ip,"*s")
                  print(string.format("Resolving %s to %s",v, ips))
                  result[v]=ips
               end)
       open=open+1
     end
  end
  
  local c=coroutine.create(qryloop)
  print("looping..")
  while count < #names do
    if coroutine.status(c)~="dead" then
      coroutine.resume(c)
    end
    net.tick()
  end
  return result
end

--net.debug(1)
   
local st,ct=net.socket_table()

print("\n\nAsync test")
local r
print(rt.format( rt.runfunction( function() r=testdns_async(g_names) end )))
print("\nResult table")
dbg.pp(r)

print("\n\nSync test")
print(rt.format( rt.runfunction( function() r=testdns_sync(g_names) end )))
print("\nResult table")
dbg.pp(r)


--[[
-- Mass test
local t={}
for i=1,10 do
  for _,v in pairs(g_names) do
    t[#t+1]=v
  end
end

dbg.pp(testdns(t))
--]]
 
print("\n\ncallback table")
dbg.pp(ct)

net.debug(0)


