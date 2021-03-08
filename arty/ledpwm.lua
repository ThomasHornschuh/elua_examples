local base=0x80060000

dbg=require "debugger"


local pwm_freq = tonumber(arg[1]) or 1000
local max= tonumber(arg[2]) or  50 -- Maximum pwm value (luminance)


local divider= bit.band(cpu.clock()/pwm_freq/256,0xffff)    -- 10 Khz PWM Freq


print(string.format("PWM Freq: %d Hz,  Divider is %d",pwm_freq,divider))


local function chk_div()
  local d=cpu.r32(base)
  dbg.assert(d==divider,string.format("Divider = %d",d))
end

-- Divider
cpu.w32(base,divider)
chk_div()


local function setled(led,v)
 
  dbg.assert(led>=1 and led<=4)

  local l=bit.lshift

  chk_div()
  cpu.w32(base+4*led,bit.bor(v.blue+0.5,l(v.green+0.5,8),l(v.red+0.5,16)))
  chk_div()
end 


local delay=0.8*10^6 / max

local sequence= {
  {red=max/2,green=max/2,blue=0,name="yellow"},
  {red=max,green=0,blue=0,name="red"},
  {red=max/2,green=0,blue=max/2,name="magenta"}, 
  {red=0,green=0,blue=max,name="blue"},
  {red=0,green=max/2,blue=max/2,name="cyan"},
  {red=0,green=max,blue=0,name="green",},
  {red=max/3,green=max/3,blue=max/3,name="white"},
  {red=0,green=0,blue=0,name="black"}
--  {red=255*0.3,green=197*0.3,blue=143*0.3,name="warm white"}
} 



local function blend(old,new,callback)

  local function d(a,b) return (b-a)/max end   

  local dr,dg,db = d(old.red,new.red), d(old.green,new.green), d(old.blue,new.blue)

  for i=1,max do 
     callback{red=old.red+dr*i,green=old.green+dg*i,blue=old.blue+db*i}
  end  
end


local work=coroutine.wrap(function()
  
  while true do
     for l=1,4 do
        setled(l,{red=0,green=0,blue=0})
     end 
     local r={math.random()*0.5,math.random()*0.5,math.random()*0.5}
     dbg.pp(r)
     for l=1,4 do
       print(l)
       for c=10,max do
         setled(l,{red=c*r[1],green=c*r[2],blue=c*r[3]})
         coroutine.yield(delay)
       end
       setled(l,{red=0,green=0,blue=0}) 
     end 

      local old={red=0,green=0,blue=0} 
      for _,v in pairs(sequence) do

        -- Blend from old color to new color  
        blend(old,v,function(nv)
           for l=1,4 do setled(l,nv) end
           coroutine.yield(delay)
        end)

        print(v.name)
        -- 2 sec. pause
        coroutine.yield(2*10^6)
        old=v
      end
  end 
end 
)

repeat
  local delay=work()
  c=uart.getchar(0,delay)
until c~=""

for l=1,4 do 
  cpu.w32(base+4*l,0)
end

