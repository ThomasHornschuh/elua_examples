
uart.setup(1,38400,8,uart.PAR_NONE,1)

local function getbyte(a)
  return #a==1 and string.byte(a) or tonumber(a)
end


local M = {}

function M.dump(s)

  if s and #s>0 then
    print(string.format("Response length: %d bytes",#s))
    local rem=#s
    local pos=1
    -- output in 16 byte chunks
    while rem>0 do
      local l = rem>16 and 16 or rem --length of current chunk
      local t = { s:byte(pos,pos+l) }
      pos = pos + l
      rem = rem - l  
      -- hex dump
      for _,v in ipairs(t) do
        term.print(string.format(" %02x ",v))
      end
      -- ASCII dump
      term.print('"')
      for _,v in ipairs(t) do
        term.print(v>=32 and string.char(v) or ".")
      end
      print('"')
    end
    print("-----")
  end  
end 

function M.request(token,token2,timeout)

    uart.write(1,token) -- either single char or hex/dec byte value
    if token2 then uart.write(1,token2) end
    uart.read(1,token2 and 2 or 1,uart.INF_TIMEOUT) -- read ourself
    tmr.delay(0,100) -- 100 us 
    local s=uart.read(1,128,timeout and timeout or 5000) -- default Timeout 5000 us
    if #s>0 then
      return s
    end  
    
end    

local args={...}
if args[1]=="msb_master" then -- called with require
    return M 
else -- command line 
    local f_endless = args[#args]=="-r" -- check wether last argument contains repeat flag
    local a=args[1]
    assert(a,"Argument needed, either char oder number")

    local token = getbyte(a)
    print(string.format("Token:  0x%x %d",token,token))

    local token2 = args[2] and getbyte(args[2]) or nil
    print(token2)

    repeat  
        local s=M.request(token,token2,10^6)     
        M.dump(s)
    until not f_endless or uart.getchar(0,uart.NO_TIMEOUT)~=""
   
end
