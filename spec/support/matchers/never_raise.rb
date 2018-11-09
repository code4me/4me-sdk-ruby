# This matcher will return:
#    1. TRUE if the code was run without exceptions
#    2. FALSE if the code was run but raised (only) the specified exception
#
# It *will* raise an exception if the block of code raises an exception other than
# (the exception specified)
#
# To use it
#
# expect {
#  code
# }.to never_raise(MySpecificException)
#
RSpec::Matchers.define :never_raise do |exception_class|
  global_result = nil

  def supports_block_expectations?
    true # or some logic
  end

  match do |block|
    begin
      block.call
    rescue exception_class => e
      global_result = "expected #{block.source_location[0]}:#{block.source_location[1]} to never raise #{exception_class.name}, but did: #{e.message}"
      false  # we did NOT never raise this exception

    rescue RSpec::Expectations::ExpectationNotMetError => exception
      global_result = "expectation failed inside block at #{block.source_location[0]}:#{block.source_location[1]}: #{exception}"
      # give us a pretty error message in addition to the error message from the exception
      raise exception

    rescue
      # handle other exceptions by reraising them. They are exceptional!!!
      # (also, no pretty error messages here)
      raise

    else
      true   # everything ran, nothing raised at all, thus code did in fact not raise anything
    end
  end

  failure_message do |player|
    global_result
  end
end