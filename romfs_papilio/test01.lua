function test01()
pack={}
local i=0 
local c
local packlen  
  
  -- wait for first packet start
  repeat
     uart.write(0,"C")
     c=uart.getchar(0,1000000)
  until string.len(c)>0    
  if string.byte(c)==1 then
    packlen=128
  elseif string.byte(c)==2 then
    packlen=1024
  else
    xmerror="Invalid start char"..c  
  end
  
  -- Get Packet
  retry=0
  for i=1,packlen+4 do
    c=uart.getchar(0,1000000)
    if string.len(c)>0 then
      pack[i]=string.byte(c)
    else
      retry=retry+1
      if retry==5 then
        xmerror="Timeout after "..i.." Bytes"
        return
      end     
    end
  end          
  uart.write(0,0x15,0x18,0x18,0x18,0x18)
  xmerror="Packet received"
end

function test02()
pack={}
local i=0 
local c
local packlen=2048  
  
  c=uart.getchar(0,10*1000000)

  for i=1,packlen do
    if string.len(c)>0 then
      pack[i]=string.byte(c)
    else
      xmerror="Timeout after "..i.." Bytes"
      return    
    end
    c=uart.getchar(0,1000000)
  end          
  xmerror="Packet received"
end

function pdump()
  local s=""
  for k,v in pairs(pack) do s=s..string.char(v) end
  print(s)
end  


 function testtimer()
 local d
 repeat
   local s=tmr.start()
   local c=uart.getchar(0,0)
   d=tmr.getdiffnow(nil,s)
   if d<0 then print(d) end
 until string.len(c)>0
 print(d)
end

  
    
  
