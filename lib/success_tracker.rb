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

    # +identifier+ is the key used for grouping success and failure cases together.
    # +notify_rule+ is a symbol identifying the code block which is evaluated to know if the error is significant or not.
    # + failure_options+ is a hash which currently can only contain the list of exceptions which should be tagged with the NonSignificantError module
    # the given block is always evaluated and the resulting errors are tagged with the NonSignificantError and reraised
    def failure(identifier, notify_rule, failure_options={})
      options[:on_failure].call(identifier) if options[:on_failure]
      store(identifier, nil)

      redis.del(identifier) if notify = rules[notify_rule].call(redis.lrange(identifier, 0,-1))

      begin
        yield if block_given?
      rescue *(failure_options[:exceptions] || [StandardError]) => error
        error.extend(NonSignificantError) unless notify
        raise
      end

      return notify
    end

    # yields the given code block and then marks success. In case a exception was triggered it marks a failure and reraises the exception (for the arguments see the #failure method)
    def track(identifier, notify_rule, failure_options={})
      yield.tap { success(identifier) }
    rescue => exception
      failure(identifier, notify_rule, failure_options) { raise exception }
    end


    # returns true if the failure ratio is higher than x (with a minimum of 10 records)
    def self.ratio_rule(ratio=0.1, minimum=10)
      lambda { |list| list.length >= minimum and list.select(&:empty?).length.to_f / list.length >= ratio }
    end

    # returns true if the last x elements have failed
    def self.sequence_rule(elements=5)
      lambda { |list| list.length >= elements && list[0..elements-1].reject(&:empty?).length == 0 }
    end

    protected
    def store(identifier, value)
      redis.lpush("#{identifier}", value)
      redis.ltrim("#{identifier}", 0, @list_length - 1)
    end
  end
end
