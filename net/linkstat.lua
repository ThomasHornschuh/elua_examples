

require("util")
local base=0x80E00000

local MDIOADDR=base+0x7e4
local MDIOWR=base+0x7e8
local MDIORD=base+0x7ec
local MDIOCTRL=base+0x7F0



local linkstat=false



function setmdio_address(op,phyaddr,regaddr)
local w=bit.bor(bit.lshift(op,10),bit.lshift(bit.band(phyaddr,0x1f),5),bit.band(regaddr,0x1f))

 -- print("Set MDIOADDR "..bit.tohex(w))
  cpu.w32(MDIOADDR,w)

end

function mdio_wait()
local w
  repeat
    w=cpu.r32(MDIOCTRL)
  until bit.isclear(w,0)
end

function mdio_read(regadr)

  mdio_wait()
  setmdio_address(1,1,regadr)
  cpu.w32(MDIOCTRL,bit.set(0,3,0)) -- set Enable and Status
  mdio_wait()
  cpu.w32(MDIOCTRL,0)
  return bit.band(cpu.r32(MDIORD),0xffff)
end

function checklink()

local t,ln
  repeat
      t=tmr.read()
      repeat
        coroutine.yield()
      until tmr.getdiffnow(nil,t)>500000
      local mdiostat=mdio_read(0x1)
      ln=bit.isset(mdiostat,2)
      if ln and not linkstat then
        print("Link established")
      elseif linkstat and not ln then
        print("Link lost")
      end
      linkstat=ln

  until false
end

local ptable = {
  coroutine.create(checklink)
}

local dispatcher=coroutine.wrap(
    function ()
    local k,c

      while true do
        for k,c in pairs(ptable) do
          coroutine.resume(c,k)
          coroutine.yield()
        end
      end
    end
)

print()

print("MDIOCTRL Reg: "..bit.tohex(cpu.r32(MDIOCTRL)))

print("MDIO Basic Mode Config:"..bit.tohex(mdio_read(0x0)))

local mdiostat=mdio_read(0x1)
print("MDIO Status Word:"..bit.tohex(mdiostat))
if bit.isset(mdiostat,2) then
  print("Link established")
end



_.always(dispatcher)


