

function timer(rate)

local count=0 
 
 cpu.set_int_handler(cpu.INT_TMR_MATCH,
    function () 
	  --cpu.w8(cpu.GPIO_BASE,count)
	  io.write(string.format(".%d",count))
	  count=count+1
	  if count>15 then 
	    count=0
	  end
    end)
 
 print(cpu.get_int_handler(cpu.INT_TMR_MATCH))   
 tmr.set_match_int(tmr.VIRT0,rate,tmr.INT_CYCLIC) 

end


function uptime()
local t,delta,l



 repeat
   t=tmr.read()
   l=0
   repeat 
     ch=uart.getchar(0,uart.NO_TIMEOUT)
     delta=tmr.getdiffnow(nil,t)
     l=l+1
   until delta>=1000000 or ch~="" 
   print(string.format("\nUptime %8.3f sec %d loops",tmr.read()/1000000,l))     
 until ch~=""
 cpu.w8(cpu.GPIO_BASE,0)
 tmr.set_match_int(tmr.VIRT0,0,tmr.INT_ONESHOT) 
end


print()
timer(0.25*1000000)
uptime()
