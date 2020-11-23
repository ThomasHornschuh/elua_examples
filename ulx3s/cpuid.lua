local r=bonfire.riscv

local ver=r.readcsr(r.mimpid)
local s

if r.cpuid then
  s=string.format("%s Version: %s mimpid: 0x%x misa: 0x%x ",pd.platform(),r.cpuid(),ver,r.readcsr(r.misa))
else 
  s=string.format("%s Version: %d.%d mimpid: 0x%x misa: 0x%x ",pd.platform(), 
       bit.rshift(ver,16),bit.band(ver,0xffff),ver,r.readcsr(r.misa))
end
print(s)

