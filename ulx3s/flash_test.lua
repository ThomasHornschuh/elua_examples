
local base=cpu.SPIFLASH_BASE -- Base Address

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
     --dbg_cnt=dbg_cnt+1
  until  bit.isclear(t,0)
  assert(bit.isset(t,1),"Expecting RX bit to be set")
  res=cpu.r32(rx)
  assert(bit.isclear(cpu.r32(status),1),"Expecting RX bit to be clear")
  return cpu.r32(rx)-- ,dbg_cnt

end


local function txrx_aw(b)

  cpu.w32(tx,b)
  return cpu.r32(rx)
end  

local function setclock(f) -- Set CLock frequency in Mhz
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

  cpu.w32(clk,div)
  assert(cpu.r32(clk)==div,"Clock divider set failed")
end


local function run_test(clock,txrx)
    setclock(clock)

    local id={}
    cpu.w32(ctl,0xfe) -- select

    local t1 =tmr.read()
    txrx(0x9f)    
    for i=1,3 do 
      id[i]=txrx(0)
    end  
    local t = tmr.getdiffnow(nil,t1)
    cpu.w32(ctl,0xff) -- deselect
    
    print(string.format("Manfufacturer ID: %02x Device ID: %02x%02x",id[1],id[2],id[3]))
    print(string.format("Execution time %f us",t))
end

print("\n")
run_test(35,txrx_aw)
run_test(0.4,txrx)



return {
  base = base,
  status=status,
  rx=rx,
  tx=tx,
  clk=clk,
  px=px,
  setclock=setclock,
  txrx=txrx_as
}
