local e=cpu.INT_ETHERNET_RECV

cpu.set_int_handler(e,function() 
          print("ethernet rx")
          cpu.get_int_flag(e,0,true)           
      end)

print(e)
cpu.get_int_flag(e,0,true) -- clear flag
--cpu.sei(e,0)


local cnt=0
repeat
  net.tick()
--  local flag=cpu.get_int_flag(e,0,true)
  if flag==1 then
    cnt=cnt+1  
    print(cnt)
   end
until uart.getchar(0,0)~=""

--cpu.cli(e,0)
cpu.set_int_handler(e,nil)
