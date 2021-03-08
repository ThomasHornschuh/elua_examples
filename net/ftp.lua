local dbg=require "debugger"

local function get_load_path()

  local parts={}
  for m in arg[0]:gmatch("/([%w%-%_%.]+)") do
     parts[#parts+1]=m
  end
  parts[#parts]=nil -- We dont want the last element (the script name itself)
  return ";/"..table.concat(parts,"/").."/?.lua"
end

-- Search ftpserver.lua in the same directory as we loaded ourself
local orgpath=package.path
package.path=package.path..get_load_path()
local f=require "ftpserver"
package.path=orgpath

--net.debug(1,"/mmc/tmp/ftp.log")



f:createServer("ftp","test")

local p,o = net.get_driver_stats()

while uart.getchar(0,0)=="" do
  net.tick()
end
dbg.call(function() f:close() end)
local t=tmr.read()
local timeout=10^6
print("wait 1 second for events to settle")
while tmr.getdiffnow(nil,t)<timeout do
  net.tick()
end

local p2,o2 = net.get_driver_stats()
print(string.format("packets: %d fifo_overflows: %d",p2-p,o2-o)) 
net.debug(0)



