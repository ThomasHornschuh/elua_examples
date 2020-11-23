
local base=cpu.SPIFLASH_BASE+2*64 -- Base Address

local ctl=base
local status=base+4
local tx=base+8
local rx=base+0xc
local clk=base+0x10



local function px(x) print(bit.tohex(x)) end


local function txrx(b)
local t,res
local dbg_cnt=0

  repeat
    t=cpu.r32(status)
  until bit.isclear(t,0)
  
  cpu.w32(tx,b)
  repeat
     t=cpu.r32(status)
     dbg_cnt=dbg_cnt+1
  until  bit.isclear(t,0)
  assert(bit.isset(t,1),"Expecting RX bit to be set")
  res=cpu.r32(rx)
  assert(bit.isclear(cpu.r32(status),1),"Expecting RX bit to be clear")
  return cpu.r32(rx),dbg_cnt

end


local function txrx_as(b)

  cpu.w32(tx,b)
  return cpu.r32(rx)
end  

local function setclock(f,cpol,cpha) -- CLock frequency in Mhz 
  local div
  if f then
    div = cpu.clock()/(2*f*10^6) -1
    if div <0 then
       div = 0
    else
       local d = math.floor(div)
       if (div-d)>0 then
         div = d+1
       else
         div = d
       end
    end
    print(string.format("Set Clk Divider Register to %d, for spi clock %f Mhz",div,cpu.clock()/((div+1)*2)/10^6))
  else
    error "Invalid or missing parameter"
  end

  assert(div<=255)
 
  local regv = bit.bor(div,bit.lshift(cpol or 0,9),bit.lshift(cpha or 0,8))
  cpu.w32(clk,regv)
  assert(cpu.r32(clk)==regv,"Clock divider set failed")
end


print("\n")
print(string.format("Base adr: %x",base))
setclock(16,1,1)


local rx1,rx2


for i=0,8 do
  local control=bit.set(bit.lshift(bit.band(i,0xf),7),11,2) -- Mode Control, Manual mode, channel 
  print(bit.tohex(control))  
  cpu.w32(ctl,0x2) -- CS  
  rx1 = txrx_as(bit.rshift(control,8))
  rx2 = txrx_as(control)
  cpu.w32(ctl,0x3) -- deslect CS
  print(string.format("%x %x", rx1,rx2))
end




