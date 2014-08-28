#!/usr/bin/env ruby
#Simple utility showing days left till certai date
require 'date'

def plur(n, singular, plural=nil)
    if n == 1
        "1 #{singular}"
    elsif plural
        "#{n} #{plural}"
    else
        "#{n} #{singular}s"
    end
end

when_it_is = Date.new(2014,9,19)
today = Date.today
nmb_of_days = when_it_is.mjd - today.mjd
puts "#{plur(nmb_of_days, 'day')}"
