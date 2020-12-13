-- Net Timer test

local d=require "debugger"

local time= tonumber(arg[1]) or 3000
local numtimers = tonumber(arg[2]) or 1 

local function run()
  local t=tmr.read()
  local stop=0

  print(string.format("Starting %d timers, at %d ms",numtimers,time))

  for i=1,numtimers do 
    -- Start timers with incrementing delays by 100ms
    net.timer(time+(i-1)*100, function(time)
      print(string.format("Time expired %f ms for timer %d",tmr.getdiffnow(nil,t)/1000,i))
      stop=stop+1
    end)
  end

d.pp(debug.getregistry())

repeat
  net.tick()
until stop==numtimers
end

run()
--run()
d.pp(debug.getregistry())

