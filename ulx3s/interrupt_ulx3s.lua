

local function setleds(data)

  if pd.board()=="BONFIRE_ARTY" then
    port=0x80000000
    cpu.w8(port+4,0) -- set port to output mode
    cpu.w8(port,data)
  elseif pd.board()=="BONFIRE_ULX3S" then
    pio.port.setdir(pio.OUTPUT,pio.PA)
    pio.port.setval(data,pio.PA)
  else -- "simulate" LEDS on console
    io.write(string.format(".%d",data))
  end

end

local function blink(rate)

local count=0
local dir=false

  cpu.set_int_handler(cpu.INT_TMR_MATCH,
      function ()
    	  setleds(bit.lshift(1,dir and (7-count) or count))
    	  count=count+1
     	  if count>7 then
          count=0
          dir = not dir
    	  end
      end)

  print(cpu.get_int_handler(cpu.INT_TMR_MATCH))
  tmr.set_match_int(tmr.VIRT0,rate,tmr.INT_CYCLIC)

end


local function uptime()
local t,delta,l

  repeat
     t=tmr.read()
     l=0
     local getchar=uart.getchar
     local diffnow=tmr.getdiffnow
     repeat
        ch=getchar(0,uart.NO_TIMEOUT)
        delta=diffnow(nil,t)
        l=l+1
     until delta>=1000000 or ch~=""
     print(string.format("Uptime %8.3f sec %d loops",tmr.read()/1000000,l))
  until ch~=""
  setleds(0)
  tmr.set_match_int(tmr.VIRT0,0,tmr.INT_ONESHOT)
end


print()
blink(0.1*1000000)

uptime()
print("exit")
