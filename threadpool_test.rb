require 'java'
require 'open-uri'
require 'threadpool'

$STATE = java.util.concurrent.ConcurrentHashMap.new

def long_process
  host = 'localhost'
  port = '3000'
  
  open("http://#{host}:#{port}/") do |f|
    f.read
  end
end

invoker = Thread.new do
  throughput = 100
  threadpool_size = 1500
  
  $STATE['errors'] = java.util.concurrent.ConcurrentHashMap.new
  
  $STATE['errors']['connection'] = 0
  $STATE['errors']['fatal'] = 0
  
  begin
    pool = ThreadPool.new(threadpool_size)
    loop do
      throughput.times do
        pool.process do
          begin
            thread_id = "#{Time.now.to_i}#{Thread.current.inspect.split(':')[-1][0..9]}"
            $STATE[thread_id] ||= java.util.concurrent.ConcurrentHashMap.new
            value = long_process
            $STATE[thread_id]['value'] = value
          rescue Errno::ECONNREFUSED
            puts "Connection refused in thread: #{thread_id}, retrying"
            $STATE['errors']['connection'] += 1
            redo
          rescue Errno::EPIPE
            puts "Errno::EPIPE in thread: #{thread_id}, retrying"
            $STATE['errors']['connection'] += 1
            redo
          rescue
            puts "Error in individual thread: #{thread_id} #{$STATE[thread_id].inspect.to_s} ", $!
            $STATE['errors']['fatal'] += 1
          end
        end
      end
      sleep 1
    end
  rescue
    p "Error in invoker: ", $!
  end
end

top = Thread.new do
  Thread.current.abort_on_exception = true
  
  poll_delay = 5
  
  total = 0
  finished = 0
  waiting = 0
  earlier_total = 0
  earlier_finished = 0
  
  loop do
    earlier_total = total
    earlier_finished = finished
    total = $STATE.size
    finished = $STATE.select { |key, stats| stats['value'] }.size
    waiting = total - finished
    
    unless total == 0
      print "",
        "T: ", total, " F: ", finished, " W: ", waiting,  
        " CE: ", $STATE['errors']['connection'], " FE: ", $STATE['errors']['fatal'],
        " IT (req/s): ", (total - earlier_total) / poll_delay, 
        " FT (req/s): ", (finished - earlier_finished) / poll_delay, "\n"
    end
    
    sleep poll_delay
  end
end

invoker.join



