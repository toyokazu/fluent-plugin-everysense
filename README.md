# fluent-plugin-everysense
Fluent Input/Output Plugin for EverySense platform

## What is EverySense?

Collecting personal data is one of the key points in IoT applications. However, it is basically difficult to search people who can provide own sensor data and to motivate people for providing own data to the world. [EverySense](http://every-sense.com/) is a platform to exchange sensor data which can define own recipe to search the data provider matching the condition. It also provide "point" mechanism to motivate people for providing own data. The "point" can be exchanged with the other sensor data or goods like general creadit card point.

This plugin provides input/output function to [EverySense platform](https://service.every-sense.com/). Data from fluentd event can be uploaded to EverySense and the data provided from EverySense can be posted into fluentd network.


## Installation

```
gem install fluent-plugin-everysense
```


## Usage

fluent-plugin-everysense has Input and Output Plugins for EverySense platform.


### Input Plugin (Fluent::Plugin::EverySenseInput)

Input Plugin can receive events from EverySense Server. It can be used via source directive in the configuration.

```
<source>
  @type everysense
  format json
  tag tag_name
  login_name your_login_name
  password your_password
  recipe_id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx
  polling_interval 30
</source>
```

- **format** (required): type of parser can be specified to parse input data. currently only json format is supported. parser plugin options can also be specified.
- **tag** (required): tag name appended to the input data inside fluentd network
- **login_name** (required): login_name to login https://service.every-sense.com/
- **password** (required): password for the login_name
- **device_id** (device_id or recipe_id is required): the target device id to obtain input data
- **recipe_id** (device_id or recipe_id is required): the target recipe id to obtain input data
- **polling_interval**: interval to poll EverySense JSON over HTTP API

Time field is added for every sensor in EverySense because sometimes remotely deployed sensors are integrated into one device. So, time field of the whole device is generated when Input Plugin received data from EverySense. It can be used only for inside the fluentd network. The real timestamp for each sensors is recorded inside JSON data and not synchronized to the time field. An example record format of the Input Plugin is as follows:

```
# device with farm_uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx
{
 "farm_uuid":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
 "device":
  [
    # list of sensors connected to this device
    { "farm_uuid":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
      "data": {
        "at": "2016-05-15 12:14:30 +0900",
        "unit":"degree Celsius",
        "value":23
      },
      "sensor_name":"collection_data_1",
      "data_class_name":"AirTemperature"
    },
    { "farm_uuid":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
      "data": {
        "at":"2016-05-15 12:14:30 +0900",
        "unit":"%RH",
        "value":30
      },
      "sensor_name":"collection_data_2",
      "data_class_name":"AirHygrometer"
    }
  ]
}
```

While fluentd record must be a map (Hash), the output of a farm, which means a set of sensors in other words a virtual device, becomes an array of sensor data. So, the keys "farm_uuid" and "device" are added to make it as a map.

### Output Plugin (Fluent::Plugin::EverySenseOutput)

Output Plugin can send events to EverySense server. It can be used via match directive. Output Plugin assumes the input format as described above.

```
<match tag_name>
  @type everysense
  login_name your_login_name
  password your_password
  device_id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx
  flush_interval 10
  aggr_type none
  <sensor>
    input_name collection_data_1
    output_name FESTIVAL_Test1_Sensor
    type_of_value Integer
  </sensor>
  <sensor>
    input_name collection_data_2
    output_name FESTIVAL_Test1_Sensor2
    type_of_value Integer
  </sensor>
</match>
```

- **login_name** (required): login_name to login https://service.every-sense.com/
- **password** (required): password for the login_name
- **device_id** (required): The target device id to submit sensor data
- **flush_interval**: Upload interval (default: 30)
- **sensor** (required): Output sensor names must be specified by sensor directive. Sensor data with the specified input_name will be uploaded to EverySense server with the output_name. If the input device data includes multiple sensor data, multiple directives can be specified. If sensor_name of input sensor data is not specified in the configuration, that sensor data will be skipped. If the sensor_names of input data are nil, sensor data will be uploaded with the number of sensor directives with the specified output_name.
  - **input_name**: sensor_name of the input sensor data.
  - **output_name**: sensor_name of the output sensor data.
  - **type_of_value**: type of value (default: Integer)

## Filter Plugin (Fluent::Plugin::EverySenseFilter)

Filter Plugin can split an EverySense Server device data into multiple fluentd events if it has multiple sensor data. It can be used via filter directive.

```
<filter tag_name>
  @type everysense
</filter>
```

The following input data from EverySense Server will be split into multiple fluentd events.

Target device data with multiple sensors in fluentd event form:

```
{
 "farm_uuid":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
 "device":
  [
    { "farm_uuid":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
      "data": {
        "at": "2016-05-15 12:14:30 +0900",
        "unit":"degree Celsius",
        "value":23
      },
      "sensor_name":"collection_data_1",
      "data_class_name":"AirTemperature"
    },
    { "farm_uuid":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
      "data": {
        "at":"2016-05-15 12:14:30 +0900",
        "unit":"%RH",
        "value":30
      },
      "sensor_name":"collection_data_2",
      "data_class_name":"AirHygrometer"
    }
  ]
}
```

will be split into the following fluentd events.

```
{
  "farm_uuid":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
  "data": {
    "at": "2016-05-15 12:14:30 +0900",
    "unit":"degree Celsius",
    "value":23
  },
  "sensor_name":"collection_data_1",
  "data_class_name":"AirTemperature"
}
{
  "farm_uuid":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx",
  "data": {
    "at":"2016-05-15 12:14:30 +0900",
    "unit":"%RH",
    "value":30
  },
  "sensor_name":"collection_data_2",
  "data_class_name":"AirHygrometer"
}
```

This filter can be used to store data into a time series database, e.g. Elasticsearch.

## Contributing

1. Fork it ( http://github.com/toyokazu/fluent-plugin-everysense/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## License

The gem is available as open source under the terms of the [Apache License Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).
