

local rtcadr=0x68

local function select(direction)

  i2c.start(0)
  local res=i2c.address(0,rtcadr,direction)
  if res then
    print("Addressing successfull")
  else
    print("Addressing failed")
  end
  return res
end


local function read_data(startadr,len)
local s

  if select(i2c.TRANSMITTER) then
    local n=i2c.write(0,startadr) -- set adr pointer
    print(string.format(" %d bytes written",n))
    if n==1 then
   --   i2c.start(0) -- repeated start
      if select(i2c.RECEIVER) then
         s=i2c.read(0,len)
         return  {s:byte(1,#s)}
      end
    end
  end
  return {}
end




local function read_all()
  local t=read_data(0,0x12)

  for k,v in pairs(t) do
    print(string.format("Register %02x:=  %d  (0x%02x)",k-1,v,v))
  end
end


local function display_time()

  repeat
    local h,m,s = bit.band(read_data(2,1)[1],0xf), read_data(1,1)[1],read_data(0,1)[1]
    print(string.format("%02x:%02x:%02x",h,m,s))
  until  uart.getchar(0,10^6)~=""
end


local function display_time_block()

  repeat
    local t= read_data(0,3)

    local h,m,s = bit.band(t[3],0xf), t[2],t[1]
    print(string.format("%02x:%02x:%02x",h,m,s))
  until  uart.getchar(0,10^6)~=""
end

i2c.setup(0,100000)

read_all()
display_time_block()

--for k,v in pairs(t) do
  --print(bit.tohex(v))
--end


