package.path=package.path..";/mmc/msb/?.lua"
local msb = require "msb_master"

local msb_info = {
    { unit="", factor=1.0, minvalue=-16000, maxvalue=16000  },
    { unit="V", factor=0.1, minvalue=-16000, maxvalue=16000  },
    { unit="A", factor=0.1, minvalue=-16000, maxvalue=16000  },
    { unit="m/s", factor=0.1, minvalue=-16000, maxvalue=16000  },
    { unit="km/h", factor=0.1, minvalue=-16000, maxvalue=16000  },
    { unit="1/min", factor=100, minvalue=-16000, maxvalue=16000  },
    { unit="Grad C", factor=0.1, minvalue=-16000, maxvalue=16000  },
    { unit="Grad", factor=0.1, minvalue=-16000, maxvalue=16000  },
    { unit="m", factor=1.0, minvalue=-16000, maxvalue=16000  },
    { unit="%", factor=1.0, minvalue=-16000, maxvalue=16000  },
    { unit="% LQI", factor=1.0, minvalue=-16000, maxvalue=16000  },
    { unit="mAh", factor=1.0, minvalue=-16000, maxvalue=16000  },
    { unit="ml", factor=1.0, minvalue=-16000, maxvalue=16000  },
    { unit="km", factor=0.1, minvalue=-16000, maxvalue=16000  },
    { unit="", factor=1.0, minvalue=-16000, maxvalue=16000  },
    { unit="Sens.", factor=1.0, minvalue=-16000, maxvalue=16000  }
}


local function tosigned(i)
  assert(i<=0xfffe,"tosigned: parameter out of range")
  if (bit.isset(i,15)) then
     return (bit.bxor(i,0xffff)+1)*-1
  else
    return i
  end
end

term.clrscr()
repeat
term.moveto(1,1)
for i=0,15 do
  local mdata = msb.request(i)
  if mdata then
    assert(#mdata==3)
    local pos,h,raw = pack.unpack(mdata,"bH")
    local v = tosigned(bit.band(raw,0xfffe)) / 2
    local info=msb_info[bit.band(h,0x0f)+1]
    local value = (v>=info.minvalue and v<=info.maxvalue) and ("%8.2f"):format(v*info.factor) or "--------"
    print(("Adr: %2d, Value: %s %s"):format(bit.rshift(h,4),value,info.unit))
  end
end 
until uart.getchar(0,0)~=""
term.clrscr()
