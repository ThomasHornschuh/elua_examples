

function thread(inst)
local i=math.random(1000)

   while true do
     print(string.format("instance: %d run: %d",inst,i))
     i=i+1
     coroutine.yield()
   end
 end
 
function showtime()
local s,a,b

  function diff_sec(t1,t2)
    return tmr.gettimediff(nil,t1,t2)/1000000
  end
   
  a=tmr.read()
  s=a
  while true do
    b=tmr.read()   
    print(string.format("Runtime %8.3f sec Delta: %8.5f sec",
          diff_sec(s,b),diff_sec(a,b)))     
    a=b    
    coroutine.yield()
  end
end



local ptable = {coroutine.create(thread),coroutine.create(thread),
                coroutine.create(showtime)}


function dispatcher()
local k,c

  while true do
	for k,c in pairs(ptable) do
	  coroutine.resume(c,k)
	  coroutine.yield()
	end 
  end	      
end 


local tickrate=1000000/tmr.getclock(tmr.VIRT0) 

print(string.format("Virtual timer resolution %d us",tickrate))
cpu.set_int_handler(cpu.INT_TMR_MATCH,coroutine.wrap(dispatcher))  
tmr.set_match_int(tmr.VIRT0,tickrate*10,tmr.INT_CYCLIC) 

-- main loop

while uart.getchar(0,uart.NO_TIMEOUT)==""  do  end -- run until key pressed
tmr.set_match_int(tmr.VIRT0,0,tmr.INT_ONESHOT) -- Switch off interrupt, very important...



   
