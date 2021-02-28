-- life.lua
-- eLua version by Bogdan Marinescu, www.eluaproject.net
-- original by Dave Bollinger <DBollinger@compuserve.com> posted to lua-l
-- modified to use ANSI terminal escape sequences
-- modified to use for instead of while
-- TH: Wrapped a TCP Server around it.

local dbg = package.loaded.debugger or function() end

local M={}

local tick=net.tick -- Picotcp

dbg()

function M.worker(socket,doloop)

    print(doloop)
    local outbuff={}

    local function write(...)

       for i,v in ipairs({...}) do
         outbuff[#outbuff+1]=tostring(v)
       end
    end


    local function flush()
       local sendbuff=table.concat(outbuff)
       local t=tmr.read()
       --dbg()
       local res,err=net.send(socket,sendbuff)
       t=tmr.getdiffnow(nil,t)/1000
       if err~=net.ERR_OK then
         print("Net error when send")
         return false
       else
         print(string.format("Send to socket [%s] took %.3f ms",tostring(socket),t))
       end
       outbuff={}
       coroutine.yield()
       return true
    end


    local function delay() -- NOTE: SYSTEM-DEPENDENT, adjust as necessary
    end

    local function ARRAY2D(w,h)
      local t = {w=w,h=h}
      for y=1,h do
        t[y] = {}
        for x=1,w do
          t[y][x]=0
        end
      end
      return t
    end

    local CELLS = {}

    -- give birth to a "shape" within the cell array
    function CELLS:spawn(shape,left,top)
      for y=0,shape.h-1 do
        for x=0,shape.w-1 do
          self[top+y][left+x] = shape[y*shape.w+x+1]
        end
      end
    end

    -- run the CA and produce the next generation
    function CELLS:evolve(next)
      local ym1,y,yp1,yi=self.h-1,self.h,1,self.h
      while yi > 0 do
        local xm1,x,xp1,xi=self.w-1,self.w,1,self.w
        while xi > 0 do
          local sum = self[ym1][xm1] + self[ym1][x] + self[ym1][xp1] +
                      self[y][xm1] + self[y][xp1] +
                      self[yp1][xm1] + self[yp1][x] + self[yp1][xp1]
          next[y][x] = ((sum==2) and self[y][x]) or ((sum==3) and 1) or 0
          xm1,x,xp1,xi = x,xp1,xp1+1,xi-1
        end
        ym1,y,yp1,yi = y,yp1,yp1+1,yi-1
      end
    end


   -- output the array to screen
    function CELLS:draw()
      local ALIVE="O"
      local DEAD="-"
      local line={}
      line[self.w]="" -- preallocate to tune performance
      for y=1,self.h do
       --coroutine.yield()
       for x=1,self.w do
         line[x]=(((self[y][x]>0) and ALIVE) or DEAD)
        end
        write(table.concat(line),"\027[K\r\n")
      end
    end

    CELLS.__index=CELLS

    -- constructor
    function CELLS:CELLS(w,h)
      local c = ARRAY2D(w,h)
      setmetatable(c,self)
      return c
    end

    --
    -- shapes suitable for use with spawn() above
    --
    local HEART = { 1,0,1,1,0,1,1,1,1; w=3,h=3 }
    local GLIDER = { 0,0,1,1,0,1,0,1,1; w=3,h=3 }
    local EXPLODE = { 0,1,0,1,1,1,1,0,1,0,1,0; w=3,h=4 }
    local FISH = { 0,1,1,1,1,1,0,0,0,1,0,0,0,0,1,1,0,0,1,0; w=5,h=4 }
    local BUTTERFLY = { 1,0,0,0,1,0,1,1,1,0,1,0,0,0,1,1,0,1,0,1,1,0,0,0,1; w=5,h=5 }

    -- the main routine
    local function LIFE(w,h,supress_out)

      local thisgen
      local nextgen
      local s_time

      local function init()
        -- create two arrays
        thisgen = CELLS:CELLS(w,h)
        nextgen = CELLS:CELLS(w,h)
        -- create some life
        -- about 1000 generations of fun, then a glider steady-state
        thisgen:spawn(GLIDER,5,4)
        thisgen:spawn(EXPLODE,25,10)
        thisgen:spawn(FISH,4,12)
      end

      if tmr~=nil then
        s_time=tmr.read()
      end

      init()

      local gen=1
      write("\027[2J")      -- ANSI clear screen

      while 1 do
        thisgen:evolve(nextgen)
        thisgen,nextgen = nextgen,thisgen
        if not supress_out then
            write("\027[H")     -- ANSI home cursor
            thisgen:draw()
            if math.pi==nil then -- lualong...
              write("Life - generation ",gen,", mem ", string.format("%d",collectgarbage('count')), " kB\n")
            else
              write("Life - generation ",gen,", mem ",string.format("%3.1f",collectgarbage('count')), " kB\n")
            end
            if not flush() then
              break
            end
        end
        gen=gen+1
        if not doloop and gen>50 then break end
        -- Start over after 250 generations
        if gen>250 then
          gen=1
          init()
        end

      end

      if s_time~=nil then
        local time_str
        s_time=tmr.getdiffnow(nil,s_time)
        if math.pi==nil then
          time_str=string.format("%d",s_time/ 1000000).." sec"
        else
          time_str=string.format("%5.3f",s_time / 1000000).." sec"
        end
        if supress_out then
          write("\027[H")     -- ANSI home cursor
          thisgen:draw()
        end
        write("Execution time ",time_str," (",s_time/1000,") ms\n")
      end
      flush()
    end



  print("Worker started, with socket",socket)
  LIFE(32,16,false)
  net.close(socket)


end -- worker



function M.dispatcher(loop)
--local k,c
local ptable={}
local l -- listener Socket
print(loop)
  local function isValid(s)
    if tick then
      return s
    else
      return s>=0
    end
  end

  local function new_connection()

    --dbg()
    local sock,ip,err=net.accept(5050,nil,0)
    if err==0 and isValid(sock) then
      print(sock,net.unpackip(ip,"*s"))
      local w=coroutine.create(M.worker)
      ptable[sock]=w
    end
    return sock
  end

  local function listen()
    while true do
      new_connection()
      coroutine.yield()
    end
  end


  if not tick then
    print("Using sync listener")
    net.listen(5050)
    ptable.listener=coroutine.create(listen)
  else
    print("Using callback listener")
    l=net.listen(5050,
       function(event)

          if event=="connect" then
            local s=new_connection()
            s:callback(function (event)
               if event=="close" then
                 dbg()
                 ptable[s]=nil
               end
            end)
          end
        end)
  end
  print("\nWaiting for new connections")
  while true do
      if tick then tick() end
      for s,c in pairs(ptable) do
        if coroutine.status(c)~="dead" then
          local f,e=coroutine.resume(c,s,loop)
          if not f then
            print("Coroutine error: ", e)
          end
        else
         -- dbg()
          ptable[s]=nil -- delete terminated threads
        end
        if tick then tick() end
      end
      if uart.getchar(0,0)~="" then
        print("\nStopping")
        for s,c in pairs(ptable) do
          if coroutine.status(c)~="dead" and  type(s)=="number" and s>=0 then
            net.close(s)
          end
        end
        break
      end
  end
  if tick then
    print("close socket: "..tostring(l))
    l:close()
  else
    net.unlisten(5050)
  end
end

-- Check for innvocation over the command line
if arg and type(arg[0])=="string" then
  M.dispatcher(arg[1]=="-l")
end

return M

