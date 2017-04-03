require 'fluent/plugin/output'
require 'fluent/event'
require 'fluent/time'
require 'fluent/plugin/everysense_proxy'

module Fluent::Plugin
  # EverySenseOutput
  # output data to EverySense server
  # this module assumes the input format follows everysense output specification
  class EverySenseOutput < Output
    include EverySenseProxy

    Fluent::Plugin.register_output('everysense', self)

    helpers :compat_parameters, :formatter, :inject

    # config_param defines a parameter. You can refer a parameter via @path instance variable
    # Without :default, a parameter is required.
    desc 'Device ID'
    config_param :device_id, :string
    desc 'Flush interval to put message to EverySense API'
    config_param :flush_interval, :integer, :default => 30
    # <sensor> is mandatory option
    # an example configuraton is shown below
    #
    # <sensor>
    #   input_name collection_data_1
    #   output_name FESTIVAL_Test1_Sensor
    #   type_of_value Integer
    # </sensor>
    # <sensor>
    #   input_name collection_data_2
    #   output_name FESTIVAL_Test1_Sensor2
    #   type_of_value Integer
    # </sensor>
    config_section :sensor, param_name: :sensors, required: true, multi: true do
      desc 'Input sensor name'
      config_param :input_name, :string, :default => nil
      desc 'Output sensor name'
      config_param :output_name, :string
      # type_of_value: "Integer", "Float", "String", etc. The same as Ruby Class name.
      desc 'Type of value'
      config_param :type_of_value, :string, :default => "Integer"
      # unit: "degree Celsius", "%RH", ...
      #desc 'unit'
      #config_param :unit, :string, :default => nil
    end

    # This method is called before starting.
    # 'conf' is a Hash that includes configuration parameters.
    # If the configuration is invalid, raise Fluent::ConfigError.
    def configure(conf)
      super
      compat_parameters_convert(conf, :formatter, :inject, :buffer, default_chunk_key: "time")
      formatter_config = conf.elements(name: 'format').first
      @formatter = formatter_create(conf: formatter_config)
      @has_buffer_section = conf.elements(name: 'buffer').size > 0
      #@sensor.each do |s|
      #  $log.debug s.to_h.inspect
      #end
      @out_sensors = {}
      @sensors.each do |sensor|
        if sensor.input_name.nil?
          @out_sensors[sensor.output_name] = sensor
        else
          @out_sensors[sensor.input_name] = sensor
        end
      end
      $log.debug @out_sensors.inspect
    end

    # This method is called when starting.
    # Open sockets or files here.
    def start
      super
      start_proxy
    end

    def prefer_buffered_processing
      @has_buffer_section
    end

    def force_type(value, out_sensor)
      case out_sensor.type_of_value
      when "Integer"
        return value.to_i
      when "Float"
        return value.to_f
      when "String"
        return value.to_s
      else
        return value.to_i
      end
    end

    # output message format of EverySense is as follows
    #
    # [
    #   {
    #     "data": {
    #       "at":"2016-04-14 17:15:00 +0900",
    #       "unit":"degree Celsius",
    #       "value":23
    #     },
    #     "sensor_name":"FESTIVAL_Test1_Sensor"
    #   },
    #   {
    #     "data": {
    #       "at":"2016-04-14 17:15:00 +0900",
    #       "unit":"%RH",
    #       "value":30
    #     },
    #     "sensor_name":"FESTIVAL_Test1_Sensor2"
    #   }
    # ]
    def transform_in_sensor(in_sensor, out_sensor) # modify sensor_name
      {
        data: {
          at: Time.parse(in_sensor["data"]["at"]),
          unit: in_sensor["data"]["unit"],
          value: force_type(in_sensor["data"]["value"], out_sensor)
        },
        sensor_name: out_sensor.output_name
      }
    end

    def get_out_sensor_by_name(input_name)
      @out_sensors[input_name]
    end

    def get_out_sensor_by_index(index)
      @out_sensors[@out_sensors.keys[index]]
    end

    # Assumed input message format is as follows
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
    def transform_in_device(in_device)
      if in_device[0]["sensor_name"].nil?
        # if first input data does not include sensor_name,
        # output_names are used in the specified order.
        return in_device.map.with_index do |in_sensor, i|
          if !get_out_sensor_by_index(i).nil?
            transform_in_sensor(in_sensor, get_out_sensor_by_index(i))
          end
        end.compact
      else
        return in_device.map do |in_sensor|
          #$log.debug in_sensor["sensor_name"]
          if @out_sensors.keys.include?(in_sensor["sensor_name"])
            transform_in_sensor(in_sensor, get_out_sensor_by_name(in_sensor["sensor_name"]))
          end
        end.compact
      end
    end

    # Emitted record inside fluentd network
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
    def put_event_stream(tag, es)
      if es.class == Fluent::OneEventStream
        es = inject_values_to_event_stream(tag, es)
        es.each do |time, record|
          $log.debug "#{tag}, #{record}"
          put_message(@formatter.format(tag, time, transform_in_device(record["device"])))
        end
      else
        es = inject_values_to_event_stream(tag, es)
        array = []
        es.each do |time, record|
          $log.debug "#{tag}, #{record}"
          device = transform_in_device(record["device"])
          array << device if !device.empty?
        end
        put_message(@formatter.format(tag, Fluent::EventTime.now, array))
      end
      $log.flush
    end

    def process(tag, es)
      put_event_stream(tag, es)
    end

    def write(chunk)
      return if chunk.empty?
      tag = chunk.metadata.tag

      put_event_stream(tag, es)
    end

    # This method is called when shutting down.
    # Shutdown the thread and close sockets or files here.
    def shutdown
      shutdown_proxy
      super
    end
  end
end
