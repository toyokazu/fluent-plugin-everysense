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


### Input Plugin (Fluent::EverySenseInput)

Input Plugin can be used via source directive in the configuration.

```
<source>
  @type everysense
  format json
  tag tag_name
  login_name your_login_name
  password your_password
  device_id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx
  polling_interval 15
</source>
```

- **format** (required): type of parser can be specified to parse input data. currently only json format is supported. parser plugin options can also be specified.
- **tag** (required): tag name appended to the input data inside fluentd network
- **login_name** (required): login_name to login https://service.every-sense.com/
- **password** (required): password for the login_name
- **device_id** (device_id or recipe_id is required): the target device id to obtain input data
- **recipe_id** (device_id or recipe_id is required): the target recipe id to obtain input data
- **polling_interval**: interval to poll EverySense JSON over HTTP API


### Output Plugin (Fluent::EverySenseOutput)

Output Plugin can be used via match directive.

```
<match tag_name>
  @type everysense
  login_name your_login_name
  password your_password
  format json
  device_id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx
</match>
```

- **format** (required): type of formatter can be specified to parse input data
- **login_name** (required): login_name to login https://service.every-sense.com/
- **password** (required): password for the login_name
- **device_id** (required): the target device id to submit sensor data


## TODO

Recipe related function is not implemented yet.


## Contributing

1. Fork it ( http://github.com/toyokazu/fluent-plugin-everysense/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
