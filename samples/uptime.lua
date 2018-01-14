function uptime()
local a,b,ch,delta
 
 print()
 ch=""
 while ch=="" do
   a=tmr.read()
   ch=uart.getchar(0,1000000) 
   b=tmr.read()
   delta=tmr.gettimediff(nil,a,b)/1000000
   print(string.format("Uptime %8.3f sec Delta: %8.5f  Raw Timer Values %8.0f %8.0f",
         b / 1000000,delta, a,b))
   if c==""  and ( delta < 0 or math.abs(delta - 1.0)>0.1 ) then 
     print("Invalid delta value detected, abort")
     return
   end        
      
 end
end

uptime()
