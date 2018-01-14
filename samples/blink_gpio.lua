

local _pin=pio.PC_0


pio.pin.setdir(pio.OUTPUT,_pin)

repeat
  if toggle then
    print("set")
    pio.pin.setval(1,_pin)
  else
    print("clear")
    pio.pin.setval(0,_pin)
  end
  toggle = not toggle
until uart.getchar(0,10^6)~=""

pio.pin.setdir(pio.INPUT,_pin)


