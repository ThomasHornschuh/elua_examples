--[[SPLIT MODULE ftp]]

--[[ A simple ftp server

 This is my implementation of a FTP server using Github user Neronix's
 example as inspriration, but as a cleaner Lua implementation that is
 suitable for use in LFS. The coding style adopted here is more similar to
 best practice for normal (PC) module implementations, as using LFS enables
 me to bias towards clarity of coding over brevity. It includes extra logic
 to handle some of the edge case issues more robustly. It also uses a
 standard forward reference coding pattern to allow the code to be laid out
 in main routine, subroutine order.

 The app will only call one FTP.open() or FTP.createServer() at any time,
 with any multiple calls requected, so FTP is a singleton static object.
 However there is nothing to stop multiple clients connecting to the FTP
 listener at the same time, and indeed some FTP clients do use multiple
 connections, so this server can accept and create multiple cxt objects.
 Each cxt object can also have a single DATA connection.

 Note that FTP also exposes a number of really private properties (which
 could be stores in local / upvals) as FTP properties for debug purposes.

 Note that this version has now been updated to allow the main methods to
 be optionally loaded lazily, and SPILT comments allow the source to be
 preprocessed for loading as either components in the "fast" Cmodule or as
 LC files in SPIFFS.
--]]
--luacheck: read globals fast file net node tmr uart wifi FAST_ftp SPIFFS_ftp

local FTP, FTPindex = {client = {}}, nil

local bufSize=8192

local dbg=require "debugger"

local function dbg_print(...)
  local args = {...}
  xpcall(function()
           print(string.format(unpack(args)))
         end,
         function(err)
            print(err)
            print(debug.traceback())
            print("Argument list")
            dbg.pp(args)
         end
   )
end


function FTP.open(...)  --[[SPLIT HERE ftp-open]]
--------------------------- Set up the FTP object ----------------------------
--       FTP has three static methods: open, createServer and close
------------------------------------------------------------------------------
end


function FTP.createServer(...)  --[[SPLIT HERE ftp-createServer]]
-- Lua: FTP:createServer(user, pass[, dbgFlag])
  local this, user, pass, dbgFlag = ...
  local cnt = 0
  this.user, this.pass, dbgFlag = user, pass, (dbgFlag and true or false)



    _G.FTP = this
    this.server =net.listen(21, function(event) -- upval: this
      -- since a server can have multiple connections, each connection
      -- has its own CXN object (table) to store connection-wide globals.
      if event=="connect" then
        local sock,ip,err=net.accept(21,nil,0)
        if err==0 then
          dbg_print("New connection from %s cmdSocket %s",net.unpackip(ip,"*s"),tostring(sock))
          local CXN; CXN = {
            validUser = false,
            loggedIn = false,
            cmdSocket = sock,
            debug     = dbg_print,
            FTP       = this,
            send      = function(rec, cb) -- upval: CXN
                CXN.debug("Sending: %s", rec)
                local r = CXN.cmdSocket:send(rec.."\r\n")
                if cb then dbg.call(cb) end
                return r
              end, --- CXN. send()
            close    = function(socket)   -- upval: CXN
                for _,s in ipairs{'cmdSocket', 'dataServer', 'dataSocket'} do
                  CXN.debug("closing CXN.%s=%s", s, tostring(CXN[s]))
                  if type(CXN[s])=='userdata' then
                    pcall(net.close, CXN[s])
                    CXN[s]= nil
                  end
                end
                CXN.FTP.client[socket] = nil
              end -- CXN.close()
            }

             local function validateUser(socket, data) -- upval: CXN
        -- validate the logon and if then switch to processing commands
                CXN.debug("Authorising: %s", data)
                local cmd, arg = data:match('([A-Za-z]+) *([^\r\n]*)')
                CXN.debug("cmd: %s arg: %s",cmd,arg)
                local msg =  "530 Not logged in, authorization required"
                cmd = cmd:upper()

                if   cmd == 'USER' then
                  CXN.validUser = (arg == CXN.FTP.user)
                  msg = CXN.validUser and
                         "331 OK. Password required" or
                         "530 user not found"

                elseif CXN.validUser and cmd == 'PASS' then

                  if arg == CXN.FTP.pass then
                    CXN.cwd = '/mmc'
                    msg = "230 Login successful. Username & password correct; proceed."
                    CXN.loggedIn=true
                  else
                    msg = "530 Try again"
                  end

                elseif cmd == 'AUTH' then
                  msg = "500 AUTH not understood"
                end

                return CXN.send(msg)
              end -- validateUser


            sock:callback(function(event)
              if event=="read" then
                local r,err = sock:recv(32768)
                assert(err==net.ERR_OK) -- TODO: improve...
                if not CXN.loggedIn then
                  validateUser(sockr,r)
                else

                  CXN.FTP.processCommand(CXN,r)
                end
              end
            end)
            this.client[sock]=CXN
            CXN.send("220 FTP server ready")
          end

      else
        dbg_print("Socket %s event: %s",tostring(this.server),event)
      end
    end) -- this.server:listen()
    print(this.server)
end


function FTP.close(this)
-- -- Lua: FTP:close()

  net.close(this.server)
  for s,cxn in pairs(this.client) do
      cxn.close(s)
  end

end



function FTP.processCommand(...)  --[[SPLIT HERE ftp-processCommand]]
----------------------------- Process Command --------------------------------
-- This splits the valid commands into one of three categories:
--   *  bare commands (which take no arg)
--   *  simple commands (which take) a single arg; and
--   *  data commands which initiate data transfer to or from the client and
--      hence need to use CBs.
--
-- Find strings are used do this lookup and minimise long if chains.
------------------------------------------------------------------------------

  local cxt, data = ...
  --dbg()
  cxt.debug("Command: %s", data)
  data = data:gsub('[\r\n]+$', '') -- chomp trailing CRLF
  local cmd, arg = data:match('([a-zA-Z]+) *(.*)')
  cmd = cmd:upper()
  local _cmd_ = '_'..cmd..'_'
  if ('_CDUP_NOOP_PASV_PWD_QUIT_SYST_'):find(_cmd_) then
    cxt.FTP.processBareCmds(cxt, cmd)
  elseif ('_CWD_DELE_MODE_PORT_RNFR_RNTO_SIZE_TYPE_'):find(_cmd_) then
    cxt.FTP.processSimpleCmds(cxt, cmd, arg)
  elseif ('_RETR_STOR_'):find(_cmd_) then
    cxt.FTP.processDataCmds(cxt, cmd, arg)
  else
    cxt.send("500 Unknown error")
  end

end --[[SPLIT IGNORE]]
function FTP.processBareCmds(...)  --[[SPLIT HERE ftp-processBareCmds]]
-------------------------- Process Bare Commands -----------------------------

local cxt, cmd = ...


  local send = cxt.send

  if cmd == 'CDUP' then
    return send("250 OK. Current directory is "..cxt.cwd)

  elseif cmd == 'NOOP' then
    return send("200 OK")

  elseif cmd == 'PASV' then
    -- This FTP implementation ONLY supports PASV mode, and the passive port
    -- listener is opened on receipt of the PASV command.  If any data xfer
    -- commands return an error if the PASV command hasn't been received.
    -- Note the listener service is closed on receipt of the next PASV or
    -- quit.
    local ip, port, pphi, pplo, i1, i2, i3, i4, _
    ip = net.local_ip()
    port = 2121
    pplo = port % 256
    pphi = (port-pplo)/256
    i1,i2,i3,i4 = net.unpackip(ip,"*n")
    cxt.FTP.dataServer(cxt, port)
    return send(
       ('227 Entering Passive Mode(%d,%d,%d,%d,%d,%d)'):format(
         i1,i2,i3,i4,pphi,pplo))

  elseif cmd == 'PWD' then
    return send('257 "/" is the current directory')

  elseif cmd == 'QUIT' then
    send("221 Goodbye", function() cxt.close(cxt.cmdSocket) end) -- upval: cxt
    return

  elseif cmd == 'SYST' then
--  return send("215 UNKNOWN")
    return send("215 UNIX Type: L8") -- must be Unix so ls is parsed correctly

  else
    error('Oops.  Missed '..cmd)
  end

end --[[SPLIT IGNORE]]
function FTP.processSimpleCmds(...)  --[[SPLIT HERE ftp-processSimpleCmds]]

------------------------- Process Simple Commands ----------------------------

local cxt, cmd, arg = ...


  local send = cxt.send

  if cmd == 'MODE' then
    return send(arg == "S" and "200 S OK" or
                               "504 Only S(tream) is suported")

  elseif cmd == 'PORT' then
    cxt.FTP.dataServer(cxt,nil) -- clear down any PASV setting
    return send("502 Active mode not supported. PORT not implemented")

  elseif cmd == 'TYPE' then
    if arg == "A" then
      cxt.xferType = 0
      return send("200 TYPE is now ASII")
    elseif arg == "I" then
      cxt.xferType = 1
      return send("200 TYPE is now 8-bit binary")
    else
      return send("504 Unknown TYPE")
    end
  end

  -- The remaining commands take a filename as an arg. Strip off leading / and ./
  arg = arg:gsub('^%.?/',''):gsub('^%.?/','')
  cxt.debug("Filename is %s",arg)

  if cmd == 'CWD' then
    if arg:match('^[%./]*$') then -- hardcoded. only allow cd /
      return send("250 CWD command successful")
    end
    return send("550 "..arg..": No such file or directory")

  elseif cmd == 'DELE' then
    if file.exists(arg) then
      file.remove(arg)
      if not file.exists(arg) then return send("250 Deleted "..arg) end
    end
    return send("550 Requested action not taken")

  elseif cmd == 'RNFR' then
    cxt.from = arg
    send("350 RNFR accepted")
    return

  elseif cmd == 'RNTO' then
    local status = cxt.from and file.rename(cxt.from, arg)
    cxt.debug("rename('%s','%s')=%s", tostring(cxt.from), tostring(arg), tostring(status))
    cxt.from = nil
    return send(status and "250 File renamed" or
                            "550 Requested action not taken")
  elseif cmd == "SIZE" then
    local st = file.stat(arg)
    return send(st and ("213 "..st.size) or
                       "550 Could not get file size.")

  else
    error('Oops.  Missed '..cmd)
  end

end --[[SPLIT IGNORE]]
function FTP.processDataCmds(...)  --[[SPLIT HERE ftp-processDataCmds]]

-------------------------- Process Data Commands -----------------------------

local cxt, cmd, arg = ...

  --dbg()
  local send, FTP = cxt.send, cxt.FTP -- luacheck: ignore FTP

  -- The data commands are only accepted if a PORT command is in scope
  if FTP.dataServer == nil and cxt.dataSocket == nil then
    return send("502 Active mode not supported. "..cmd.." not implemented")
  end

  cxt.getData, cxt.setData = nil, nil

  arg = arg:gsub('^%.?/',''):gsub('^%.?/','')

  arg = cxt.cwd.."/"..arg

  if cmd == "LIST" or cmd == "NLST" then
    -- There are
    local fileSize, nameList, pattern = file.list(), {}, '.'

    arg = arg:gsub('^-[a-z]* *', '') -- ignore any Unix style command parameters
    arg = arg:gsub('^/','')  -- ignore any leading /

    if #arg > 0 and arg ~= '.' then -- replace "*" by [^/%.]* that is any string not including / or .
      pattern = arg:gsub('*','[^/%%.]*')
    end

    for k, _ in pairs(fileSize) do
      if k:match(pattern) then
        nameList[#nameList+1] = k
      else
        fileSize[k] = nil
      end
    end
    table.sort(nameList)

    function cxt.getData(c) -- upval: cmd, fileSize, nameList
      local list, user = {}, c.FTP.user
      for i = 1,10 do -- luacheck: no unused
        if #nameList == 0 then break end
        local f = table.remove(nameList, 1)
        list[#list+1] = (cmd == "LIST") and
          ("-rw-r--r-- 1 %s %s %6u Jan  1 00:00 %s\r\n"):format(user, user, fileSize[f], f) or
          (f.."\r\n")
      end
      return table.concat(list)
    end

  elseif cmd == "RETR" then
    --dbg()
    local f = io.open(arg, "r")
    local size = 0
    if f then -- define a getter to read the file
      function cxt.getData(c) --
        local buf = f:read(bufSize)
        if buf then size = size+#buf end
        if not buf then f:close(); f = nil; cxt.debug("file size: %d",size) end
        return buf
      end -- cxt.getData()
    end

  elseif cmd == "STOR" then
    local f = io.open(arg, "w")
   
    if f then -- define a setter to write the file
      cxt.debug("opened file %s",arg)
      function cxt.setData(c, rec) -- luacheck: ignore c -- upval: f (, arg)
        cxt.debug("writing %u bytes to %s", #rec, arg)
        return f:write(rec)
      end -- cxt.saveData(rec)
      function cxt.fileClose(c) -- luacheck: ignore c -- upval: f (,arg)
        cxt.debug("closing %s", arg)
        f:close(); f = nil
      end -- cxt.close()
    end

  end

  send((cxt.getData or cxt.setData) and "150 Accepted data connection" or
                                        "451 Can't open/create "..arg)
  -- if cxt.getData and cxt.dataSocket then
  --   net.timer(1,function()
  --      cxt.debug ("poking sender to initiate first xfer")
  --      cxt.sender(cxt.dataSocket)
  --   end)

  --end

end --[[SPLIT IGNORE]]
function FTP.dataServer(...)  --[[SPLIT HERE ftp-dataServer]]
----------------------------- Data Port Routines -----------------------------
-- These are used to manage the data transfer over the data port.  This is
-- set up lazily either by a PASV or by the first LIST NLST RETR or STOR
-- command that uses it.  These also provide a sendData / receiveData cb to
-- handle the actual xfer. Also note that the sending process can be primed in
--
----------------   Open a new data server and port ---------------------------

local cxt, n = ...

  if cxt.dataServer then pcall(cxt.dataServer.close, cxt.dataServer) end -- close any existing listener
  if n then
    -- Open a new listener if needed. Note that this is only used to establish
    -- a single connection, so ftpDataOpen closes the server socket
    cxt.dataServer = net.listen(n, function(event) -- upval: cxt
          if event=="connect" then
              local sock,ip,err=net.accept(n,nil,0)
              assert(err==net.ERR_OK)
              cxt.FTP.ftpDataOpen(cxt,sock,ip,n)
          else
            cxt.debug("%s event on  dataSvr %s",event,tostring(cxt.dataServer))
          end
        end)
    cxt.debug("Listening on Data port %u, server %s",n, tostring(cxt.dataServer))
  else
    cxt.dataServer = nil
    cxt.debug("Stopped listening on Data port",n)
  end

end
function FTP.ftpDataOpen(cxt, dataSocket,cip,sport)
----------------------- Connection on FTP data port ------------------------

local sip = net.local_ip()

  cxt.debug("Opened data socket %s to %s:%u from %s", tostring(dataSocket),net.unpackip(sip,"*s"),sport,net.unpackip(cip,"*s") )
  cxt.dataSocket = dataSocket
  dataSocket:setoption(net.OPT_SNDBUF,bufSize*2)

  
  dataSocket:callback(function(event)
    local case = {

      write = function()
       cxt.sender()
      end,
      read = function() 
        r = dataSocket:recv(bufSize)
        if #r>0 and cxt.setData then
          cxt:setData(r)
        end  

      end,
      close = function()
        cxt:cleardown(dataSocket,1)
      end,  
      fin = function()
        cxt.debug("dataSocket %s fin event",tostring(dataSocket))
        cxt.dataSocket=nil
      end
    }

    local f=case[event]
    if f then
      dbg.call(f)
      --f()
    else
      cxt.debug("%s event on %s",event,tostring(dataSocket))
    end
  end)
  cxt.debug("closing dataserver %s",tostring(cxt.dataServer))
  cxt.dataServer:close()
  cxt.dataServer = nil

  function cxt.cleardown(cxt, skt, cdtype) 
   
    cdtype = cdtype==1 and "disconnection" or "reconnection"
    local which = cxt.setData and "setData" or (cxt.getData and cxt.getData or "neither")
    cxt.debug("Cleardown entered from %s with %s", cdtype, which)
    if cxt.setData then
      cxt:fileClose()
      cxt.setData = nil
      cxt.send("226 Transfer complete.")
    else
      cxt.getData, cxt.sender = nil, nil
    end
    cxt.debug("Clearing down data socket %s", tostring(skt))
   
  end




  -- dataSocket:on("receive", function(skt, rec) -- upval: cxt, on_hold

  --   local rectype = cxt.setData and "setData" or (cxt.getData and cxt.getData or "neither")
  --   cxt.debug("Received %u data bytes with %s", #rec, rectype)

  --   if not cxt.setData then return end

  --   if not on_hold then
  --     -- Cludge to stop the client flooding the ESP SPIFFS on an upload of a
  --     -- large file. As soon as a record arrives assert a flow control hold.
  --     -- This can take up to 5 packets to come into effect at which point the
  --     -- low priority unhold task is executed releasing the flow again.
  --     cxt.debug("Issuing hold on data socket %s", tostring(skt))
  --     skt:hold(); on_hold = true
  --     node.task.post(node.task.LOW_PRIORITY,
  --          function() -- upval: skt, on_hold
  --            cxt.debug("Issuing unhold on data socket %s", tostring(skt))
  --            pcall(skt.unhold, skt); on_hold = false
  --          end)
  --   end

  --   if not cxt:setData(rec) then
  --     cxt.debug("Error writing to SPIFFS")
  --     cxt:fileClose()
  --     cxt.setData = nil
  --     cxt.send("552 Upload aborted. Exceeded storage allocation")
  --   end
  -- end)

  
  cxt.sender=coroutine.wrap(function(skt) -- upval: cxt
    local size=0
    repeat
      --cxt.debug ("entering sender")
      if cxt.getData then
        skt = skt or cxt.dataSocket
        local rec = cxt:getData()
        if rec and #rec > 0 then
          --cxt.debug("Sending %u data bytes", #rec)         
          while true do
            local sent=skt:send(rec)
            size=size+sent
            --cxt.debug("sent %d bytes",sent)
            if sent==#rec then
              break
            elseif sent>0 then
              rec = rec:sub(sent+1)
            end            
            coroutine.yield()
          end
          
        else       
          cxt.debug("Send of data completed: %d bytes",size)
          skt:close()
          cxt.send("226 Transfer complete.")
          cxt.getData, cxt.dataSocket = nil, nil
          size=0
        end
      end  
      skt=coroutine.yield()
    until false  
  end)

  -- dataSocket:on("sent", cxt.sender)
  -- dataSocket:on("disconnection", function(skt) return cxt:cleardown(skt,1) end) -- upval: cxt
  -- dataSocket:on("reconnection",  function(skt) return cxt:cleardown(skt,2) end) -- upval: cxt

  -- -- if we are sending to client then kick off the first send
  -- if cxt.getData then cxt.sender(cxt.dataSocket) end

end --[[SPLIT HERE]]
return FTP --[[SPLIT IGNORE]]
