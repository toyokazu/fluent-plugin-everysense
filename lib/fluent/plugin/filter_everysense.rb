require 'fluent/plugin/output'
require 'fluent/event'

module Fluent::Plugin
  # EverySenseFilter
  # Split EverySense data into multiple output entries
  # to store each datum separately
  class EverySenseFilter < Filter
    Fluent::Plugin.register_filter('everysense', self)

    def filter_stream(tag, es)
      new_es = Fluent::MultiEventStream.new
      es.each do |time, record|
        # log.debug "filter_everysense: #{record}"
        split_record(time, record, new_es)
      end
      new_es
    end

    private

    def split_record(time, record, new_es)
      log.debug "split_record: #{record.inspect}"
      # add each sensor as an event of fluentd
      record[:device].each do |sensor|
        new_es.add(Time.parse(sensor["data"]["at"]), sensor)
      end
    end
  end
end
