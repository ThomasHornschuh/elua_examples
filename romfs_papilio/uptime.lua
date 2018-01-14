function uptime()
local t,c;

 c=""
 while c=="" do
   t=tmr.read()
   print("Uptime (seconds):", t / 1000000)
   c=uart.getchar(0,1000000) 
 end
end

uptime()
