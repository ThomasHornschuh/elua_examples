
-- ESP-01 GPIO Mapping
--gpio0, gpio2 = 3, 4
i2c.setup(0, i2c.SLOW) -- call i2c.setup() only once

require("ds3231")


local weekdays = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday"}

repeat
-- Get current time
  local second, minute, hour, weekday, day, month, year = ds3231.getTime();
  print(string.format("Time & Date: %02d:%02d:%02d, %s  %02d.%02d.%02d", hour, minute, second,weekdays[weekday],day, month, year))
until  uart.getchar(0,10^6)~=""


-- Don't forget to release it after use
ds3231 = nil
package.loaded["ds3231"]=nil
