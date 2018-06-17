-- Microbenchmark for bit operations library. Public domain.

os={}

function os:clock()
-- Returns time in seconds  
  return tmr.read()/tmr.getclock()
end

local base = 0

local function bench(name, t)
  local n = 1000
  repeat
    local tm = os.clock()
    t(n)
    tm = os.clock() - tm
    if tm > 1 then
      local ns = tm*1000/(n/1000000)
      io.write(string.format("%-15s %6.1f ns   n=%d \n", name, ns-base,n))
      return ns
    end
    n = n + n
  until false
end

-- The overhead for the base loop is subtracted from the other measurements.
base = bench("loop baseline", function(n)
  local x = 0; for i=1,n do x = x + i end
end)

bench("tobit", function(n)
  local f = bit.tobit or bit.cast
  local x = 0; for i=1,n do x = x + f(i) end
end)

bench("bnot", function(n)
  local f = bit.bnot
  local x = 0; for i=1,n do x = x + f(i) end
end)

bench("bor/band/bxor", function(n)
  local f = bit.bor
  local x = 0; for i=1,n do x = x + f(i, 1) end
end)

bench("shifts", function(n)
  local f = bit.lshift
  local x = 0; for i=1,n do x = x + f(i, 1) end
end)

bench("rotates", function(n)
  local f = bit.rol
  local x = 0; for i=1,n do x = x + f(i, 1) end
end)

bench("bswap", function(n)
  local f = bit.bswap
  local x = 0; for i=1,n do x = x + f(i) end
end)

