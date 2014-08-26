require 'test_helper'
require 'minitest/unit'

class ActiveRecordConnectionPoolTest < ActiveSupport::TestCase

  # Test that the bug in AR ConnectionPool is fixed, either becuase of a local
  # patch (temporarily in config/initializers/patch/connection_pool.rb)
  # or because of a future version of Rails. 
  # See https://github.com/rails/rails/issues/5330
  #
  # This is fixed in current rails, but it's painful enough to debug that we're going
  # to leave our own regression test in here 
  def test_threaded_with_connection
    # Neccesary to have a checked out connection in thread
    # other than one we will test, in order to trigger bug
    # we are testing fix for.
    main_thread_conn = ActiveRecord::Base.connection_pool.checkout

    aThread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.connection # need to do something AR to trigger the checkout

        reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)

        assert reserved_thread_ids.keys.include?( Thread.current.object_id ), "thread should be in reserved connections"
      end
      reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)
      assert !reserved_thread_ids.keys.include?( Thread.current.object_id ), "thread should not be in reserved connections"
    end
    aThread.join

    ActiveRecord::Base.connection_pool.checkin main_thread_conn

    reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)
    assert !reserved_thread_ids.keys.include?( aThread.object_id ), "thread should not be in reserved connections"
  end

  # Our own monkey-patched behavior
  def test_forbid_implicit_checkout
    assert_raises(ActiveRecord::ImplicitConnectionForbiddenError) do
      t = Thread.new do
        ActiveRecord::Base.forbid_implicit_checkout_for_thread!
        ActiveRecord::Base.connection
      end
      t.join
    end
  end
  
end
