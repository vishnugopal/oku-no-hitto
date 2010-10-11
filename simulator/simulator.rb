require 'sinatra/async'

class Simulator < Sinatra::Base
 register Sinatra::Async

 aget '/' do 
   delay = 7 + (rand * 10).to_i
   EM.add_timer(delay.to_i) { body { "#{delay}" } }
 end
end