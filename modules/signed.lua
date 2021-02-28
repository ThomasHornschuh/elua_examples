local M={}


function M.tosigned(i)
    assert(i<=0xffffffff,"tosigned: parameter out of range")
    if (bit.isset(i,31)) then
       return (bit.bxor(i,0xffffffff)+1)*-1
    else
      return i
    end
end

return M
