local getinst=bonfire.riscv.readminstret

-- Length operator
local function test1()
  local a={}
  local t1=getinst()
  for i=1,100 do 
    a[#a+1]="x"
  end
  local delta=getinst()-t1
  print(string.format("test1 Number of CPU instructions %d",delta))
end

local function test2()
-- index
  local a={}
  local t1=getinst()
  for i=1,100 do
    a[i]="x"
  end
  local delta=getinst()-t1
  print(string.format("test2 Number of CPU instructions %d",delta))
end

local function test3()
  -- index
    local a={1,2,3}
    local t1=getinst()
    for i=1,100 do
      local dummy=#a
    end
    local delta=getinst()-t1
    print(string.format("test3 Number of CPU instructions %d",delta))
end

local function test4()
  -- index
    local a={1,2,3}
    local t1=getinst()
    for i=1,100 do
      local dummy=#a+1
    end
    local delta=getinst()-t1
    print(string.format("test4 Number of CPU instructions %d",delta))
end

local function test5()
  -- index
    
    local t1=getinst()
    for i=1,100 do
      local dummy=i
    end
    local delta=getinst()-t1
    print(string.format("test5 Number of CPU instructions %d",delta))
end


test1()
test2()
test3()
test4()
test5()


