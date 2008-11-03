require 'pp'

class RTunnel::LeakTracker
  def self.start
    logged_thread do
      sleep 10
      begin
        objects = Hash.new 0

        while true
          last_objects = objects.dup
          ObjectSpace.each_object do |o|
            objects[o.class] += 1
          end

          objects.reject!{|k,v| ! last_objects.has_key? k }  unless last_objects.empty?

          new_objects = objects.dup
          objects.each do |(klass, count)|
            new_objects.delete klass  if count < last_objects[klass]  # has been GC'ed, "cant be leaking"
          end
          objects = new_objects

          PP.pp objects.sort_by{|(k,cnt)| cnt }.reverse[0..10], STDERR

          sleep 10
        end
      rescue Object
        STDERR.puts $!.inspect
        STDERR.puts $!.backtrace.join("\n")
      end
    end
  end
end
