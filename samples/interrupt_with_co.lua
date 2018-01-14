require("life_bench")

handler=coroutine.wrap(
  function () 
      local count=0
      while true do 
		  cpu.w8(cpu.GPIO_BASE,count)
		  coroutine.yield()
		  count=count+1
		  if count>15 then 
		    count=0
		  end
	  end 
    end
  )




function main()
  cpu.set_int_handler(cpu.INT_TMR_MATCH,handler)    
  tmr.set_match_int(tmr.VIRT0,0.25*1000000,tmr.INT_CYCLIC) 
  run() -- Life_bench
  tmr.set_match_int(tmr.VIRT0,0,tmr.INT_CYCLIC) 
  cpu.w8(cpu.GPIO_BASE,0)

end

main()

