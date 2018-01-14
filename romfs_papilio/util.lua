-- Simple helpers to make interactive work more convenient

_ = { }

_.maxlevel=5

_.p = print

function _.pt(tbl)

local level=0

  local function doprint(t)
    for k,v in pairs(t) do
      print(string.rep(" ",level) ..string.format("%s = %s",k,tostring(v)))
      if type(v)=="table"or type(v)=="romtable" and level<=_.maxlevel and v~=tbl then
        level=level+1
        doprint(v)
        level=level-1
      end
    end
  end

  doprint(tbl)
end

function _.px(...)

   for i,v in ipairs{...} do
     io.write(string.format("%X  ",v))
   end
   io.write("\n")

end

