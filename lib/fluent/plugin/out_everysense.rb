module Fluent
  class EverySenseOutput < BufferedOutput
    require 'fluent/plugin/everysense_proxy'
    include EverySenseProxy

    Plugin.register_output('everysense', self)

    # config_param defines a parameter. You can refer a parameter via @path instance variable
    # Without :default, a parameter is required.
    #desc 'Flush interval to put message to EverySense API'
    #config_param :flush_interval, :integer, :default => 15

    # This method is called before starting.
    # 'conf' is a Hash that includes configuration parameters.
    # If the configuration is invalid, raise Fluent::ConfigError.
    def configure(conf)
      super
      configure_formatter(conf)
    end

    def configure_formatter(conf)
      @formatter = Plugin.new_formatter(@format)
      @formatter.configure(conf)
    end

    # This method is called when starting.
    # Open sockets or files here.
    def start
      super
      start_proxy
    end

    def add_send_time(record)
      if @send_time
        # send_time is recorded in ms
        record.merge({@send_time_key => Time.now.instance_eval { self.to_i * 1000 + (usec/1000) }})
      else
        record
      end
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |tag, time, record|
        $log.debug "#{tag}, #{@formatter.format(tag, time, add_send_time(record)).chomp}\n"
        put_message(@formatter.format(tag, time, add_send_time(record)))
      end
      $log.flush
    end

    # This method is called when shutting down.
    # Shutdown the thread and close sockets or files here.
    def shutdown
      shutdown_proxy
      super
    end
  end
end
