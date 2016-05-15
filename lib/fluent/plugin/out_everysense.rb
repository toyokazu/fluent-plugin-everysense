module Fluent
  # EverySenseOutput
  # output data to EverySense server
  # this module assumes the input format follows everysense output specification
  class EverySenseOutput < BufferedOutput
    require 'fluent/plugin/everysense_proxy'
    include EverySenseProxy

    Plugin.register_output('everysense', self)

    # config_param defines a parameter. You can refer a parameter via @path instance variable
    # Without :default, a parameter is required.
    desc 'Device ID'
    config_param :device_id, :string
    desc 'Flush interval to put message to EverySense API'
    config_param :flush_interval, :integer, :default => 30
    # aggr_type: "none", "avg", "max", "min"
    desc 'Aggregation type'
    config_param :aggr_type, :string, :default => "none"
    # <sensor> is mandatory option
    # an example configuraton is shown below
    #
    # <sensor>
    #   input_name collection_data_1
    #   output_name FESTIVAL_Test1_Sensor
    #   type_of_value Integer
    # </sensor>
    # <sensor>
    #   input_name collection_data_1
    #   output_name FESTIVAL_Test1_Sensor2
    #   type_of_value Integer
    # </sensor>
    config_section :sensor, required: true, multi: true do
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
      configure_formatter(conf)
      #@sensor.each do |s|
      #  $log.debug s.to_h.inspect
      #end
      @sensor_hash = {}
      @sensor.each do |sensor|
        if sensor.to_h[:input_name].nil?
          @sensor_hash[sensor.to_h[:output_name]] = sensor.to_h
        else
          @sensor_hash[sensor.to_h[:input_name]] = sensor.to_h
        end
      end
      $log.debug @sensor_hash.inspect
    end

    def configure_formatter(conf)
      #@formatter = Plugin.new_formatter(@format)
      #@formatter.configure(conf)
    end

    # This method is called when starting.
    # Open sockets or files here.
    def start
      super
      start_proxy
    end

    def format(tag, time, record)
      $log.debug "tag: #{tag}, time: #{time}, record: #{record}"
      [tag, time, record].to_msgpack
    end

    def force_type(value)
      case @type_of_value
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
    def transform_sensor_data(sensor_data, output_name) # modify sensor_name
      {
        data: {
          at: Time.parse(sensor_data["data"]["at"]),
          unit: sensor_data["data"]["unit"],
          value: force_type(sensor_data["data"]["value"])
        },
        sensor_name: output_name
      }
    end

    def get_output_name_by_name(input_name)
      @sensor_hash[input_name][:output_name]
    end

    def get_output_name_by_index(index)
      @sensor_hash[@sensor_hash.keys[index]][:output_name]
    end

    def transform_device_data(device_data)
      if device_data[0]["sensor_name"].nil?
        # if first input data does not include sensor_name,
        # output_names are used in the specified order.
        return device_data.map.with_index do |sensor_data, i|
          if !get_output_name_by_index(i).nil?
            transform_sensor_data(sensor_data, get_output_name_by_index(i))
          end
        end.compact
      end
      device_data.map do |sensor_data|
        #$log.debug sensor_data["sensor_name"]
        if @sensor_hash.keys.include?(sensor_data["sensor_name"])
          transform_sensor_data(sensor_data, get_output_name_by_name(sensor_data["sensor_name"]))
        end
      end.compact
    end

    def avg(chunk)
      device_data_list = []
      chunk.msgpack_each do |tag, time, device_data|
        device_data_list << transform_device_data(device_data)
      end
      avg_device_data = device_data_list[0]
      device_data_list[1..-1].each do |device_data|
        avg_device_data.each_with_index do |avg_sensor_data, i|
          avg_sensor_data[:data][:at].to_i += device_data[i][:data][:at].to_i
          avg_sensor_data[:data][:value] += device_data[i][:data][:value]
        end
      end
      avg_device_data.each_with_index do |avg_sensor_data, i|
        # average time
        avg_sensor_data[:data][:at] = Time.at((avg_sensor_data[:data][:at] / device_data_list.size).to_i)
        # average value
        avg_sensor_data[:data][:value] = force_type(avg_sensor_data[:data][:value] / device_data_list.size)
      end
      $log.debug avg_device_data.to_json
      put_message(avg_device_data.to_json)
    end

    def max(chunk)
      # TODO
    end

    def min(chunk)
      # TODO
    end

    def write(chunk)
      case @aggr_type
      when "none"
        chunk.msgpack_each do |tag, time, record|
          #$log.debug transform_device_data(record["json"]).to_json
          put_message(transform_device_data(record["json"]).to_json)
        end
      when "avg", "max", "min"
        method(@aggr_type).call(chunk)
      else
        raise NotImplementedError, "specified aggr_type is not implemented."
      end
    end

    # This method is called when shutting down.
    # Shutdown the thread and close sockets or files here.
    def shutdown
      shutdown_proxy
      super
    end
  end
end
