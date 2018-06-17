local band, bxor = bit.band, bit.bxor
local rshift,rol = bit.rshift,bit.rol

 
local m = 10000
if m < 2 then m = 2 end
local count = 0
local p = {}

for i=0,(m+31)/32 do p[i] = -1 end

for i=2,m do
  if band(rshift(p[rshift(i, 5)], i), 1) ~= 0 then
    count = count + 1
    for j=i+i,m,i do
      local jx = rshift(j, 5)
      p[jx] = band(p[jx], rol(-2, j))
    end
  end
end



io.write(string.format("Found %d primes up to %d\n", count, m))
--for k,v in pairs(p) do print(k,bit.tohex(v)) end
