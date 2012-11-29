require 'test/unit'
require 'shoulda'
require 'success_tracker'

class SuccessTracker::BaseTest < Test::Unit::TestCase
  def setup
    @redis = Redis.new
  end

  def teardown
    @redis.del("success_tracker_test_key")
  end

  should "store a success in the given redis key" do
    success_tracker = SuccessTracker::Base.new(@redis)
    success_tracker.success("success_tracker_test_key")

    assert_equal ["1"], @redis.lrange("success_tracker_test_key", 0, -1)
  end

  should "store an error in the given redis key" do
    success_tracker = SuccessTracker::Base.new(@redis)
    success_tracker.failure("success_tracker_test_key", :percent_10)

    assert_equal [""], @redis.lrange("success_tracker_test_key", 0, -1)
  end

  should "yield the success callback on success" do
    success_tracker = SuccessTracker::Base.new(@redis, :callbacks => { :success => lambda { |identifier| @identifier = "success: #{identifier}" } })
    success_tracker.success("success_tracker_test_key")

    assert_equal "success: success_tracker_test_key", @identifier
  end

  should "yield the failure callback on failure" do
    success_tracker = SuccessTracker::Base.new(@redis, :callbacks => { :failure => lambda { |identifier| @identifier = "failure: #{identifier}" } })
    success_tracker.failure("success_tracker_test_key", :percent_10)

    assert_equal "failure: success_tracker_test_key", @identifier
  end

  should "raise an ArgumentError when initializing with unknown options" do
    assert_raise(ArgumentError) do
      SuccessTracker::Base.new(@redis, :foo => "bar")
    end
  end

  should "allow a maximum number of records" do
    success_tracker = SuccessTracker::Base.new(@redis)
    105.times { success_tracker.success("success_tracker_test_key") }
    assert_equal 100, @redis.lrange("success_tracker_test_key", 0, -1).length
  end

  should "yield failure block" do
    success_tracker = SuccessTracker::Base.new(@redis)
    success_tracker.failure("success_tracker_test_key", :percent_10) do
      @output_from_block = true
    end

    assert @output_from_block
  end

  should "track success" do
    success_tracker = SuccessTracker::Base.new(@redis)
    success_tracker.track("success_tracker_test_key", :percent_10) { "working block" }
    assert_equal ["1"], @redis.lrange("success_tracker_test_key", 0, -1)
  end

  should "return result from block on #track" do
    success_tracker = SuccessTracker::Base.new(@redis)
    assert_equal "result", success_tracker.track("success_tracker_test_key", :percent_10) { "result" }
  end

  should "track failure and reraise tagged exception" do
    success_tracker = SuccessTracker::Base.new(@redis)
    begin
      success_tracker.track("success_tracker_test_key", :percent_10) { raise ArgumentError }
      flunk "should have raised an exception before"
    rescue => exception
      assert ArgumentError === exception, "exception should be an ArgumentError"
      assert SuccessTracker::NonSignificantError === exception, "exception should be a NonSignificantError"
    end
    assert_equal [""], @redis.lrange("success_tracker_test_key", 0, -1)
  end

  context "ratio_rule" do
    should "return false until threshold of x percent is reached" do
      rule = SuccessTracker::Base.ratio_rule(0.1)
      assert !rule.call(["1"] * 10 + [""] * 1), "should return false when threshold is not reached"
      assert rule.call(["1"] * 9 + [""] * 1), "should return true when threshold is reached"
    end

    should "always return true before minimum" do
      rule = SuccessTracker::Base.ratio_rule(0.1, 3)
      assert !rule.call([""] * 2), "should return false when below minimum"
      assert rule.call([""] * 3), "should return true when minimum is reached"
    end
  end

  context "sequence_rule" do
    should "return false until threshold of x percent is reached" do
      rule = SuccessTracker::Base.sequence_rule(5)
      assert !rule.call([""] * 4 + ["1"] * 5), "should return false before having x failures in a row"
      assert rule.call([""] * 5 + ["1"] * 5), "should return true when having x failures in a row"
    end
  end

  context "over threshold" do
    setup do
      @success_tracker = SuccessTracker::Base.new(@redis, :rules => { :never_below_threshold => lambda { |list| true } })
    end

    should "reraise errors from failure block not extended with module" do
      begin
        @success_tracker.failure("success_tracker_test_key", :never_below_threshold) do
          raise NoMethodError
        end
        flunk "should raise exception before"
      rescue NoMethodError => exception
        assert !(SuccessTracker::NonSignificantError === exception), "should not have the module when meeting the error condition"
      end
    end

    should "empty the list" do
      @success_tracker.failure("success_tracker_test_key", :never_below_threshold)
      assert_equal [], @redis.lrange("success_tracker_test_key", 0, -1)
    end
  end

  context "below threshold" do
    setup do
      @success_tracker = SuccessTracker::Base.new(@redis, :rules => { :always_below_threshold => lambda { |list| false } })
    end

    should "reraise errors from failure block extended with module" do
      begin
        @success_tracker.failure("success_tracker_test_key", :always_below_threshold) do
          raise NoMethodError
        end
        flunk "should raise exception before"
      rescue NoMethodError => exception
        assert SuccessTracker::NonSignificantError === exception, "should have the module before meeting the error condition"
      end
    end

    should "not reraise errors from failure block extended with module" do
      begin
        @success_tracker.failure("success_tracker_test_key", :always_below_threshold, :exceptions => [ ArgumentError ]) do
          raise NoMethodError
        end
        flunk "should raise exception before"
      rescue NoMethodError => exception
        assert !(SuccessTracker::NonSignificantError === exception), "should not have the module for an NoMethodError"
      end
    end

    should "not empty the list" do
      @success_tracker.failure("success_tracker_test_key", :always_below_threshold)
      assert_equal [""], @redis.lrange("success_tracker_test_key", 0, -1)
    end
  end
end
