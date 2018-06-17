

local port=5050
local wait=0.2*10^6 -- 200ms wait time

function echo_worker(socket)

  net.send(socket,"Enter text to Echo,stop with empty line\n\r")
  repeat
    local buffer,err=net.recv(socket,32767)
    if err==net.ERR_OK then

      if #buffer==0 or buffer:find("^[\r]?\n") then
        return
      else
        net.send(socket,buffer)
      end
    end
  until err~=net.ERR_OK
end

function main()
    print(string.format("\nWaiting for connections on Port %d",port))
    net.listen(port)
    repeat
      local socket,remote,err=net.accept(port,nil,wait)
      if err==net.ERR_OK then
        print("Connection from IP: "..net.unpackip(remote,"*s"))
        net.unlisten(port) -- Stop listening because we are busy
        echo_worker(socket)
        net.close(socket) -- Just to be sure
        print("Connection closed")
        net.listen(port)
      end
    until uart.getchar(0,uart.NO_TIMEOUT)~=""
    net.unlisten(port) -- clean up
end

main()
