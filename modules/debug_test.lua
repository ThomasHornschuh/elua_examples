dbg=require("debugger")

function test()
  local s=[[
{host}
{path}
]]
  return s:gsub("{(%w+)}",function(capture)
     dbg()
     return "[replaced: "..capture .."]"
   end)
end

dbg()
print(test())
dbg()
