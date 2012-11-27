require "success_tracker/version"
require 'redis'

module SuccessTracker
  module NonSignificantError
  end

  class Base
    attr_accessor :options, :rules, :redis, :list_length

    def initialize(redis, options={})
      @redis = redis
      @rules = {
        :percent_10 => self.class.ratio_rule(0.1),
        :sequence_of_5 => self.class.sequence_rule(5),
      }.merge(options.delete(:rules) || {})
      @options = options
      @list_length = 100
    end

    def success(identifier)
      options[:on_success].call(identifier) if options[:on_success]
      store(identifier, "1")
    end

    def failure(identifier, notify_rule)
      options[:on_failure].call(identifier) if options[:on_failure]
      store(identifier, nil)

      redis.del(identifier) if notify = rules[notify_rule].call(redis.lrange(identifier, 0,-1))

      begin
        yield if block_given?
      rescue => error
        error.extend(NonSignificantError) unless notify
        raise
      end

      return notify
    end

    # returns true if the failure ratio is higher than x (with a minimum of 10 records)
    def self.ratio_rule(ratio=0.1, minimum=10)
      lambda { |list| list.length >= minimum and list.select(&:empty?).length.to_f / list.length >= ratio }
    end

    # returns true if the last x elements have failed
    def self.sequence_rule(elements=5)
      lambda { |list| list.length >=elements && list[0..elements-1].reject(&:empty?).length == 0 }
    end

    protected
    def store(identifier, value)
      redis.lpush("#{identifier}", value)
      redis.ltrim("#{identifier}", 0, @list_length - 1)
    end
  end
end
