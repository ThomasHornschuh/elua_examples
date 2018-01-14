
function thread(inst) 
   for i=1,10 do
     print(string.format("instance: %d run: %d",inst,i))
     coroutine.yield(i)
   end  
   return -1
 end


print("\nCoroutine Demo")
c1=coroutine.create(thread)
c2=coroutine.create(thread)

 repeat
   b,v1=coroutine.resume(c1,100)
   b,v2=coroutine.resume(c2,200)
   
   
 until v1==-1 or v2==-1
 
   
