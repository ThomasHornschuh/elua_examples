package.path=package.path..";/mmc/msb/?.lua"
local msb=require "msb_master"
local dbg=require "debugger"

local function decode_gpsrec(s)
    if s then 
        
        local t = { pack.unpack(s,"b3<l2<lb") }
        --dbg.pp(t)
        assert(#t==8)
        local rec = {
          adr = t[2],
          class = t[3],
          len = t[4],
          lon = t[5] * 1e-7,
          lat = t[6] * 1e-7,
          height = t[7] / 1000,
          chksum = t[8]
        }
        

        --dbg.pp(rec)
        return t[1],rec -- position of next record, current record
   end
end 

local function format_gpsdata(r)

  return ("GPS Lat: %10.6f Lon: %10.6f  Height over sealevel: %8.2f"):format(r.lat,r.lon,r.height)
  
end  


local function char(v)
-- Save variant of string:char which never throws an error
  local c
  if pcall(function() c=string.char(v) end) then
    return c
  else
    return ""
  end
end


local function main()
  local adr = arg[1] and tonumber(arg[1]) or 0
  if arg[1] and not tonumber(arg) then
    local f=io.open(arg[1],"r")
    if f then
      print(("Replaying file %s"):format(arg[1]))
      local data = f:read("*all")
      f:close()
      local pos=1
     
      repeat
        print(("rec at pos %d"):format(pos))
        local next,rec = decode_gpsrec(data:sub(pos))
        pos = pos + next - 1 
        print(format_gpsdata(rec))
        term.print("(C)ontinue or any other key abort: ")
        if char(term.getchar()):lower()~="c" then
          return
        end
        print()
      until pos>=#data  
      return 
    end
  end  
  -- fall through to Bus read mode
  local s=msb.request(0x80,adr,10^5)
  msb.dump(s)
  -- Append to recording file
  local f=io.open("/mmc/tmp/msb_data.rec","a+")
  f:write(s)
  f:close()
  local _,rec = decode_gpsrec(s)
  print(format_gpsdata(rec))
end 

main()
