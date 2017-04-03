require 'fluent/plugin/input'
require 'fluent/event'
require 'fluent/time'
require 'fluent/plugin/everysense_proxy'

module Fluent::Plugin
  class EverySenseInput < Input
    include EverySenseProxy

    Fluent::Plugin.register_input('everysense', self)

    helpers :thread, :compat_parameters, :parser

    desc 'The tag of the event.'
    config_param :tag, :string
    desc 'Polling interval to get message from EverySense API'
    config_param :polling_interval, :integer, :default => 60
    desc 'Device ID'
    config_param :device_id, :string, :default => nil
    desc 'Recipe ID'
    config_param :recipe_id, :string, :default => nil

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

    def configure(conf)
      super
      configure_parser(conf)
    end

    def configure_parser(conf)
      compat_parameters_convert(conf, :parser)
      parser_config = conf.elements('parse').first
      @parser = parser_create(conf: parser_config)
    end

    def start
      #raise StandardError.new if @tag.nil?
      super
      start_proxy
      @proxy_thread = Thread.new(&method(:get_loop))
    end

    def get_loop
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

    def parse_time(record)
      if record["data"]["at"].nil?
        $log.debug "Since time_key field is nil, Fluent::EventTime.now is used."
        Fluent::EventTime.now
      else
        @parser.parse_time(record["data"]["at"])
      end
    end

    # Converted record for emission
    # [
    #   {"farm_uuid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
    #    "device":
    #     [
    #       {
    #         "farm_uuid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
    #         "sensor_name": "collection_data_1",
    #         "data_class_name": "AirTemperature",
    #         "data": {
    #           "at": "2016-05-12 21:38:52 UTC",
    #           "memo": null,
    #           "value": 23,
    #           "unit": "degree Celsius"
    #         }
    #       },
    #       {
    #         "farm_uuid": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
    #         "sensor_name": "collection_data_2",
    #         "data_class_name": "AirHygrometer",
    #         "data": {
    #           "at": "2016-05-12 21:38:52 UTC",
    #           "memo": null,
    #           "value": 30,
    #           "unit": "%RH"
    #         }
    #       }
    #     ]
    #   }
    # ]
    def emit(messages)
      begin
        time, record = @parser.parse(messages) do |time, record|
          [time, record]
        end
        #puts "time: #{time.inspect}"
        #puts "record: #{record.inspect}"
        if record.is_a?(Array) && record[0].is_a?(Array) # Multiple devices case
          mes = Fluent::MultiEventStream.new
          record.each do |single_record|
            # use timestamp of the first sensor (single_record[0])
            mes.add(parse_time(single_record[0]), {
              "farm_uuid": single_record[0]["farm_uuid"],
              "device": single_record
            })
          end
          router.emit_stream(@tag, mes)
        elsif record.is_a?(Array) && record[0].is_a?(Hash) # Single device case
          # use timestamp of the first sensor (single_record[0])
          router.emit(@tag, parse_time(record[0]), {
            "farm_uuid": record[0]["farm_uuid"],
            "device": record
          })
        else # The other case
          raise Fluent::Plugin::Parser::ParserError, "Unexpected input format."
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
