uart.setup(1,115200,8,0,1)
uart.set_buffer(1,65536)
--local f=io.open("/mmc/tmp/esp.log","w")
if arg[1]=="reset" then
  print("Reseting ESP")
  pio.port.setdir(pio.OUTPUT,pio.PB)
  pio.port.setval(0,pio.PB) -- wifi_en to low
  tmr.delay(nil,10000) -- 10ms
  pio.port.setdir(pio.INPUT,pio.PB)
  print(pio.port.getval(pio.PB))
  pio.port.setval(2,pio.PB) -- wifi_en = 1 gpio12=0
  tmr.delay(nil,0.2*10^6) -- 200ms
  pio.port.setval(3,pio.PB) -- wifi_en =1 gpio12=1
end


local c=''
while string.byte(c)~=0x1a do

   c=uart.getchar(0,0)
   if c~="" and string.byte(c)~=0x1a then uart.write(1,c) end
   local t=uart.read(1,1024,0)
   if t~="" then 
     uart.write(0,t)
     if f then
        f:write(t)
     end
   end
end
print("\n")  
if f then f:close() end
uart.set_buffer(1,0) -- Disable buffer

