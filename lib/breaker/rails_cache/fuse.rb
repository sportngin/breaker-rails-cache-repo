module Breaker
  module RailsCache
    class Fuse
      attr_accessor :name, :failure_threshold, :retry_threshold, :retry_timeout, :timeout, :half_open_timeout, :breaker_error_class, :failure_count_ttl

      def initialize(name, options={})
        self.name = name
        options = defaults.dup.merge(options)
        self.failure_threshold = options[:failure_threshold]
        self.retry_timeout = options[:retry_timeout]
        self.timeout = options[:timeout]
        self.half_open_timeout = options[:half_open_timeout]
        self.breaker_error_class = options[:breaker_error_class]
        self.failure_count_ttl = options[:failure_count_ttl]
        self.state || set_value(:state, options[:state])
      end

      def defaults
        Repo.config
      end

      def update(attributes)
        attributes.each do |attr, value|
          send("#{attr}=",value)
        end
      end

      def ==(other)
        other.instance_of?(self.class) && name == other.name
      end

      def eql?(other)
        self == other
      end

      def hash
        [self.class, self.name].hash
      end

      def set_value(key, value, options={})
        Rails.cache.write(key_name(key), value, options)
      end

      def get_value(key)
        Rails.cache.read(key_name(key))
      end
      def inc_value(key, value)
        if Rails.cache.read(key_name(key))
          Rails.cache.increment(key_name(key), value)
        else
          Rails.cache.write(key_name(key), 1, raw:true, expires_in: failure_count_ttl)
          return 1
        end
      end

      def key_name(key)
        "BREAKER_#{self.name}_#{key}"
      end

      def state
        @state ||= get_value(:state)
      end

      def state=(state)
        set_value(:state, state)
        @state = state
      end

      def retry_threshold
        @retry_threshold ||= get_value(:retry_threshold)
      end

      def retry_threshold=(retry_threshold)
        set_value(:retry_threshold, retry_threshold)
        @retry_threshold = retry_threshold
      end

      def failure_count
        @failure_count ||= get_value(:failure_count).to_i
      end

      def failure_count=(value)
        if value.zero?
          Rails.cache.delete(key_name(:failure_count))
          @failure_count = 0
        else
          @failure_count = inc_value(:failure_count, 1)
        end
      end
    end
  end
end
