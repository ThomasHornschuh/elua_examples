-- life.lua
-- eLua version by Bogdan Marinescu, www.eluaproject.net
-- original by Dave Bollinger <DBollinger@compuserve.com> posted to lua-l
-- modified to use ANSI terminal escape sequences
-- modified to use for instead of while
-- TH: Wrapped a TCP Server around it.
dbg=require("debugger")

require "util"

local worker = function(socket)


    local outbuff={}

    local write=function(...)

       for i,v in ipairs(arg) do
         outbuff[#outbuff+1]=tostring(v)
       end
    end


    local flush=function()
       local sendbuff=table.concat(outbuff)
       local t=tmr.read()
       --dbg()
       local res,err=net.send(socket,sendbuff)
       t=tmr.getdiffnow(nil,t)/1000
       if err~=net.ERR_OK then
         print("Net error when send")
         return false
       else
         --if t>100 then
           print(string.format("Send to socket %d took %.3f ms",socket,t))
         --end
       end
       outbuff={}
       coroutine.yield()
       return true
    end

    ALIVE="O"       DEAD="-"

    function delay() -- NOTE: SYSTEM-DEPENDENT, adjust as necessary
    end

    function ARRAY2D(w,h)
      local t = {w=w,h=h}
      for y=1,h do
        t[y] = {}
        for x=1,w do
          t[y][x]=0
        end
      end
      return t
    end

    _CELLS = {}

    -- give birth to a "shape" within the cell array
    function _CELLS:spawn(shape,left,top)
      for y=0,shape.h-1 do
        for x=0,shape.w-1 do
          self[top+y][left+x] = shape[y*shape.w+x+1]
        end
      end
    end

    -- run the CA and produce the next generation
    function _CELLS:evolve(next)
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
    function _CELLS:draw()

      for y=1,self.h do
       for x=1,self.w do
          write(((self[y][x]>0) and ALIVE) or DEAD)
        end
        write("\r\n")
      end
    end

    -- constructor
    function CELLS(w,h)
      local c = ARRAY2D(w,h)
      c.spawn = _CELLS.spawn
      c.evolve = _CELLS.evolve
      c.draw = _CELLS.draw
      return c
    end

    --
    -- shapes suitable for use with spawn() above
    --
    HEART = { 1,0,1,1,0,1,1,1,1; w=3,h=3 }
    GLIDER = { 0,0,1,1,0,1,0,1,1; w=3,h=3 }
    EXPLODE = { 0,1,0,1,1,1,1,0,1,0,1,0; w=3,h=4 }
    FISH = { 0,1,1,1,1,1,0,0,0,1,0,0,0,0,1,1,0,0,1,0; w=5,h=4 }
    BUTTERFLY = { 1,0,0,0,1,0,1,1,1,0,1,0,0,0,1,1,0,1,0,1,1,0,0,0,1; w=5,h=5 }

    -- the main routine
    function LIFE(w,h,supress_out)
      -- create two arrays
      local thisgen = CELLS(w,h)
      local nextgen = CELLS(w,h)
      local s_time
      if tmr~=nil then
        s_time=tmr.read()
      end


      -- create some life
      -- about 1000 generations of fun, then a glider steady-state
      thisgen:spawn(GLIDER,5,4)
      thisgen:spawn(EXPLODE,25,10)
      thisgen:spawn(FISH,4,12)

      -- run until break
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
        if gen>50 then break end

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



  LIFE(32,16,false)
  net.close(socket)


end -- worker



function dispatcher()
--local k,c
local ptable


  function listen()
    local w
    while true do
      local sock,ip,err=net.accept(5050,nil,0)
      if err==0 and sock>=0 then
        print(sock,net.unpackip(ip,"*s"))
        w=coroutine.create(worker)
        ptable[sock]=w
        --dbg()
      end
      coroutine.yield()
    end
  end

  ptable={ listener=coroutine.create(listen) }

  print("\nWaiting for new connections")
  while true do
      for s,c in pairs(ptable) do
        if coroutine.status(c)~="dead" then
          coroutine.resume(c,s)
        else
         -- dbg()
          ptable[s]=nil -- delete terminated threads
        end
      end
      if uart.getchar(0,0)~="" then
        print("\nStopping")
        for s,c in pairs(ptable) do
          if coroutine.status(c)~="dead" and  type(s)=="number" and s>=0 then
            net.close(s)
          end
        end
        return
      end
  end
end


dispatcher()
net.unlisten(5050)

