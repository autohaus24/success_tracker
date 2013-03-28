# SuccessTracker

Allows you to track success and failure of tasks and define thresholds for unexpected failure conditions. When the threshold is met, the failure method returns true (otherwise false). This can be used to define in code what to do when the failure condition is met. The failure method gets the name of a rule as a second parameter. This rule is used to define when a failure should be seen as unexpected. There are some rules defined as default (:percent\_10 which fails when there is at least a 10 percent failure rate with a minimum of 10 records and :sequence\_of\_5 which fails when there are at least 5 failures in a row).

## Installation

Add this line to your application's Gemfile:

    gem 'success_tracker'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install success_tracker

## Usage

```ruby
$success_tracker = SuccessTracker::Base.new(redis_connection)
$success_tracker.success('mytask')
if $success_tracker.failure('mytask', :percent_10)
  puts "reached the threshold!"
end
```

You can define additional rules with your own code blocks or use the sequence_rule or ratio_rule class methods for this task. These code blocks get an array of the recorded notifications as parameters which can have between 0 and 100 elements all having either an empty string (failure) or a "1" (success).

```ruby
$success_tracker = SuccessTracker::Base.new(redis_connection, :rules => {
  :percent_50 => SuccessTracker::Base.ratio_rule(0.5)
})
$success_tracker.failure('mytask', :percent_50)
```

You can give a block to the failure method which is always yielded. In case the block raises an exception and the failure condition is not met, the exception is extended with the SuccessTracker::NonSignificantError module. This can then be used in rescue statements to define what should only happen if the handled exception was not triggered with a failure condition met.

```ruby
$success_tracker = SuccessTracker::Base.new(redis_connection)
$success_tracker.failure('mytask', :percent_10) do
  raise ArgumentError
end

# You can also use it to exclude these errors from Airbrake reporting.
Airbrake.configure do |config|
  config.ignore_by_filter do |notice|
    SuccessTracker::NonSignificantError === notice.exception
  end
end
```

By default all StandardErrors are extended but in the options you can define an array with the exceptions which should be tagged.

```ruby
$success_tracker = SuccessTracker::Base.new(redis_connection)
$success_tracker.failure('mytask', :percent_10, :exceptions => [ MySpecialError ]) do
  raise ArgumentError # will not be tagged because it is the wrong exception type
end
```

You can also define on_success and on_failure callbacks which run on success or failure and get the identifier given to the success or failure method as a parameter. Use this for example to track success and failure rates in StatsD.

```ruby
# assuming you have statsd-client stored in $statsd
$success_tracker = SuccessTracker::Base.new(redis_connection, {
    :on_success => lambda { |identifier| $statsd.increment("#{identifier}.success") },
    :on_failure => lambda { |identifier| $statsd.increment("#{identifier}.failure") }
  }
)
```

## Requirements

* Redis

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT License. Copyright 2013 autohaus24 GmbH
