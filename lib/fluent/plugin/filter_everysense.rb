module Fluent
  # EverySenseFilter
  # Split EverySense data into multiple output entries
  # to store each datum separately
  class EverySenseFilter < Filter
    Plugin.register_filter('everysense', self)

    def filter_stream(tag, es)
      new_es = MultiEventStream.new
      es.each {|time, record| split(time, record, new_es)}
      new_es
    end

    private

    def split(time, record, new_es)
      if record['json'].instance_of?(Array)
        record['json'].each { |r| new_es.add(time, r) }
      else
        new_es.add(time, record)
      end
    end
  end
end
