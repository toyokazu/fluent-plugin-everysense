module Fluent
  class EverySenseInput < Input
    require 'fluent/plugin/everysense_proxy'
    include EverySenseProxy

    Plugin.register_input('everysense', self)

    desc 'Tag name assigned to inputs'
    config_param :tag, :string, :default => nil # TODO: mandatory option
    desc 'Polling interval to get message from EverySense API'
    config_param :polling_interval, :integer, :default => 15
    config_param :recv_time, :bool, :default => false
    config_param :recv_time_key, :string, :default => "recv_time"

    # Define `router` method of v0.12 to support v0.10 or earlier
    unless method_defined?(:router)
      define_method("router") { Fluent::Engine }
    end

    def configure(conf)
      super
      configure_parser(conf)
    end

    def configure_parser(conf)
      @parser = Plugin.new_parser(@format)
      @parser.configure(conf)
    end

    def start
      raise StandardError.new if @tag.nil?
      super
      start_proxy
      @proxy_thread = Thread.new do
        while (true)
          begin
            message = get_message
            $log.debug "get_message: #{message}"
            emit(message) if !message.nil?
            sleep @polling_interval
          rescue Exception => e
            $log.error :error => e.to_s
            $log.debug(e.backtrace.join("\n"))
            #$log.debug_backtrace(e.backtrace)
            sleep @polling_interval
          end
        end
      end
    end

    def add_recv_time(record)
      if @recv_time
        # recv_time is recorded in ms
        record.merge({@recv_time_key => Time.now.instance_eval { self.to_i * 1000 + (usec/1000) }})
      else
        record
      end
    end

    def parse(message)
      @parser.parse(message) do |time, record|
        if time.nil?
          $log.debug "Since time_key field is nil, Fluent::Engine.now is used."
          time = Fluent::Engine.now
        end
        $log.debug "#{time}, #{add_recv_time(record)}"
        return [time, add_recv_time(record)]
      end
    end

    def emit(message)
      begin
        router.emit(@tag, *parse(message))
      rescue Exception => e
        $log.error :error => e.to_s
        $log.debug_backtrace(e.backtrace)
      end
    end

    def shutdown
      super
      @proxy_thread.kill
      shutdown_proxy
    end
  end
end
