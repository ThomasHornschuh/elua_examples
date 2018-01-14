
--local modulename=...

moduleName= "i2c_util"
local M = {}
_G[moduleName] = M

M.idRTC=0x68
M.idEEPROM=0x57

function M.select(port,id,direction)

  i2c.start(port)
  local res=i2c.address(port,id,direction)
  if not res then
    i2c.stop(port)
  end
  return res
end

local function write_index(port,index,f16)

  if index<0 then
    print "I2C index must be positive"
    return -1
  end

  if not f16 then
    return i2c.write(port,index)
  else
    local msb,lsb=bit.band(bit.rshift(index,8),0xff),bit.band(index,0xff)
    --print(string.format("Setting long address %2x %2x",msb,lsb))
    return i2c.write(port,msb,lsb)
  end
end

function M.read_data_string(port,id,startadr,len,f16)
local s

  if M.select(port,id,i2c.TRANSMITTER) then
    local n=write_index(port,startadr,f16) -- set adr pointer
    if n>=1 then
      if M.select(port,id,i2c.RECEIVER) then
         s=i2c.read(port,len)
         i2c.stop(port)
         return s
      end
    else
      print("Set adr pointer failed")
    end
  else
    print(string.format("Device %2x not found",id))
  end
  i2c.stop(port)
  return ""
end

function M.read_data(port,id,startadr,len,f16)

local s=M.read_data_string(port,id,startadr,len,f16)

  return {s:byte(1,#s)}

end

function M.write_data(port,id,startadr,f16,...)

  if M.select(port,id,i2c.TRANSMITTER) then
    local n=write_index(port,startadr,f16)
    if n>=1 then
      n=i2c.write(port,...)
      i2c.stop(port)
      return n
    end
  else
    i2c.stop(port)
    print(string.format("Device %2x not found",id))
    return -1
  end

end



local function read_all()

  local s=tmr.read()
  local t=M.read_data(0,M.idRTC,0,0x13)
  s=tmr.getdiffnow(nil,s)
  print("DS3231 registers:")
  for k,v in pairs(t) do
    print(string.format("Register %02x:=  %d  (0x%02x)",k-1,v,v))
  end
  print(string.format("Read time %d us, %8.3f us/byte",s, s / (#t+3) ))
end

local function read_temperature()
local t=M.read_data(0,M.idRTC,0x11,2)
local i=t[1]

   -- sign extend
   if bit.isset(i,7) then
     i=bit.bor(i,0xffffff00)-2^32
   end
   return i + bit.rshift(t[2],6)*0.25
end





local function display_time_block()

  local t= M.read_data(0,M.idRTC,0,3)
  local h,m,s = bit.band(t[3],0x3f), t[2],t[1]
  print(string.format("Clock: %02x:%02x:%02x",h,m,s))

end

i2c.setup(0,100000)

--Write Test to register 0x7 (Alarm seconds)
--print(M.write_data(0,M.idRTC,0x7,false,0x51))

read_all()
print(string.format("Temperature %3.2f C",read_temperature()))




--repeat
  display_time_block()
--until uart.getchar(0,10^6)~=""

local function write_eeprom(txt,reducedLog)
local pollcount,polltime=0,0

  local function poll()
    local s=tmr.read()
    local success

    repeat
      pollcount=pollcount+1
      i2c.start(0)
      success=i2c.address(0,M.idEEPROM,i2c.TRANSMITTER)
      i2c.stop(0)
    until success or tmr.getdiffnow(nil,s)>10^6
    polltime=polltime+tmr.getdiffnow(nil,s)
    return success
  end

  print(string.format("Write length %d",#txt))

  local pageSize=32
  local total=0
  for i=0, #txt/pageSize  do
    local p=i*pageSize+1
    local page=txt:sub(p,p+pageSize-1)
    if not reducedLog then
      print(string.format("Page %d, len %d : %s",i,#page,page))
    end
    if #page>0 then
      local s=tmr.read()
      if not poll() then
        print("Timeout abort")
        return -1
      end
      local written=M.write_data(0,M.idEEPROM,i*pageSize,true, page)
      s=tmr.getdiffnow(nil,s)
      total=total+s
      if not reducedLog then
        print(string.format("Wrote %d bytes in %8.3f ms",written,s/1000))
      end
    end
  end
  print(string.format("Total time %8.3f ms, pollcount: %d, polltime %8.3f ms ",total/1000,pollcount,polltime/1000))
end

print("EEPROM Test")
print("Initalizing EEPROM")
write_eeprom(string.rep("\0",4096),true)

local txt
repeat
  io.write("Enter String: ");
  txt=io.read()
  write_eeprom(txt,true)

  print("Read back from EEPROM:")
  local readback=M.read_data_string(0,M.idEEPROM,0,#txt,true)
  print(readbeak==txt) -- and "OK" or "not OK")
  print(readback)
until txt==""


