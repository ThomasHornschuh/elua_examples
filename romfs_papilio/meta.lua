function dump(t)
  for k,v in pairs(t) do print(k,v) end
end


x="test"
print(x)
z=getmetatable(x)
print(z)
dump(z)


