local g=bonfire.gdbserver
if g then
  uart.setup(1,115200,8,0,1)
  local f=assert(io.open("/mmc/ulx3s/server.py","r"))
  local scode = f:read("*a")
  f:close()
  print(string.format("Send server.py to ESP32, %d bytes",#scode))
  if #scode>0 then
    -- Send in raw repl mode
    uart.write(1,0x1, scode,0x4)
  end
  -- get initial messages
  local t= tmr.read()
  repeat
    s=uart.read(1,2048,0)
    io.stdout:write(s)
  until s:match("UP") or tmr.getdiffnow(nil,t)>2*10^6
  assert(s:match("UP"),"server.py upload and start failure")
  if arg[1]~="test" then
    g.init()
  end
else
  error "eLua compiled without gdbserver"
end