require "util"

print('****************')

local t={}
for i=1,500 do
  t[i]='x'
end

print(#t)
local s=table.concat(t)
print(#s)



