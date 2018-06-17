
local M={}

function M.disk_bench(s)
local fname="/mmc/bench.txt"
local t=tmr.read()
local f=io.open(fname,"w")

  print(string.format("Testing with %d bytes",#s))
  f:write(s)
  f:close(s)
  local diff=tmr.getdiffnow(nil,t)
  print(string.format("Write time : %.3f ms, %d Bytes/sec ",diff/(10^3),#s*(10^6)/diff))
  t=tmr.read()
  f=io.open(fname,"r")
  local sres=f:read("*a")
  f:close()
  diff=tmr.getdiffnow(nil,t)
  print(string.format("%d bytes read back",#sres))
  print(string.format("Read time : %.3f ms, %d Bytes/sec ",tmr.getdiffnow(nil,t)/(10^3),#sres*(10^6)/diff))
  return sres
end

return M

--local s10k=string.rep("#",10000)
--disk_bench(s10k)
