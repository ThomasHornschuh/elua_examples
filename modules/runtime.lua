
local M={}

local function _run(chunk)

local t=tmr.read()
local err=nil
  
  xpcall(chunk,function(e) 
     err=e
     print("Runtime error: "..e) 
  end)
  return tmr.getdiffnow(nil,t), err
end

function M.runscript(path)
local c,err=loadfile(path)

  if err then
    print(err)
    return 0,err
  else
    return _run(c)  
  end
    
end 

function M.runstring(s)
local c,err=loadstring(s)

  if err then
    print(err)
    return 0,err
  else
    return _run(c)  
  end

end

function M.format(t)
 return string.format("Runtime %7.5f seconds",t/10^6)
end

function M.time(path)

  print(M.format(M.runscript(path)))

end

if arg and arg[1] then
  print(string.format("Loading and measuring %s",arg[1]))
  M.time(arg[1])
else  
  return M
end
  
