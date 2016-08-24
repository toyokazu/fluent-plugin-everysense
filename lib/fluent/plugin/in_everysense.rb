module Fluent
  class EverySenseInput < Input
    require 'fluent/plugin/everysense_proxy'
    include EverySenseProxy

    Plugin.register_input('everysense', self)

    config_param :format, :string, :default => 'json'

    # currently EverySenseParser is only used by EverySense Plugin
    # Parser is implemented internally.
    # received message format of EverySense is as follows
    #
    # [
    #   [
    #     {
    #       "farm_uuid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
    #       "sensor_name": "collection_data_1",
    #       "data_class_name": "AirTemperature",
    #       "data": {
    #         "at": "2016-05-12 21:38:52 UTC",
    #         "memo": null,
    #         "value": 23,
    #         "unit": "degree Celsius"
    #       }
    #     },
    #     {
    #       "farm_uuid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
    #       "sensor_name": "collection_data_2",
    #       "data_class_name": "AirHygrometer",
    #       "data": {
    #         "at": "2016-05-12 21:38:52 UTC",
    #         "memo": null,
    #         "value": 30,
    #         "unit": "%RH"
    #       }
    #     }
    #   ]
    # ]
    class EverySenseParser
      def initialize(format, parser)
        case format
        when 'json'
          @parser = parser
          return
        when 'xml'
          raise NotImplementedError, "XML parser is not implemented yet."
        else
          raise NotImplementedError, "XML parser is not implemented yet."
        end
      end

      # TODO: parser should be impelented prettier way...
      # currently once parse JSON array is parsed and in map loop
      # each message is re-formatted to JSON. After that it is re-parsed
      # by fluent JSON parser which supports time_format etc. options...
      def parse(messages)
        #$log.debug messages
        JSON.parse(messages).map do |message|
          #$log.debug message
          @parser.parse(message.to_json) do |time, record|
            yield(time, record)
          end
        end
      end
    end

    desc 'Tag name assigned to inputs'
    config_param :tag, :string, :default => 'everysense'
    desc 'Polling interval to get message from EverySense API'
    config_param :polling_interval, :integer, :default => 60
    desc 'Device ID'
    config_param :device_id, :string, :default => nil
    desc 'Recipe ID'
    config_param :recipe_id, :string, :default => nil

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
      @everysense_parser = EverySenseParser.new(@format, @parser)
    end

    def start
      #raise StandardError.new if @tag.nil?
      super
      start_proxy
      @proxy_thread = Thread.new do
        while (true)
          begin
            messages = get_messages
            emit(messages) if !(messages.nil? || messages.empty?)
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

    def parse(messages)
      @everysense_parser.parse(messages) do |time, record|
        if time.nil?
          $log.debug "Since time_key field is nil, Fluent::Engine.now is used."
          time = Fluent::Engine.now
        end
        #$log.debug "#{time}, #{record}"
        {time: time, record: record}
      end
    end

    def emit(messages)
      begin
        parse(messages).each do |msg|
          router.emit(@tag, msg[:time], {json: msg[:record]})
        end
      rescue Exception => e
        $log.error :error => e.to_s
        $log.debug_backtrace(e.backtrace)
      end
    end

    def shutdown
      @proxy_thread.kill
      shutdown_proxy
      super
    end
  end
end
