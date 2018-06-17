if not net then
  print("network support missing, abort")
  return
end

print("Waiting for connection on port 5050")
local s,r,e
--repeat
  s,r,e=net.accept(5050) --,nil,3*1000000);
  --if e==-1 then io.write(".") end
--until e~=-1 or uart.getchar(0,uart.NO_TIMEOUT)~=""
print(s,net.unpackip(r,"*s"),e)
if s>=0 then
  print("Connection from IP: "..net.unpackip(r,"*s"))
  while true do
      local buff,err=net.recv(s,2048,nil,500000) -- timeout 0.5 sec
      if err==net.ERR_OK and  #buff>0  then
        io.write(buff)
      end
      if not ( err==net.ERR_TIMEOUT or err==net.ERR_OK) then
        print("Error:",err)
        return
      end
      if  not ( err==net.ERR_TIMEOUT or err==net.ERR_OK)  or uart.getchar(0,uart.NO_TIMEOUT)~="" then
        print("closing")
        net.close(s)
        return
      end
  end
else
  print(string.format("Network error %d\n",e))
end


