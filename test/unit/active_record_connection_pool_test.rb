# Test that the bug in AR ConnectionPool is fixed, either becuase of a local
# patch (temporarily in config/initializers/patch/connection_pool.rb)
# or because of a future version of Rails. 
# See https://github.com/rails/rails/issues/5330

require 'test_helper'
require 'test/unit'

class ActiveRecordConnectionPoolTest < Test::Unit::TestCase

  def test_threaded_with_connection
        # Neccesary to have a checked out connection in thread
        # other than one we will test, in order to trigger bug
        # we are testing fix for.
        main_thread_conn = ActiveRecord::Base.connection_pool.checkout

        aThread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.connection # need to do something AR to trigger the checkout

            reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)

            assert reserved_thread_ids.has_key?( Thread.current.object_id ), "thread should be in reserved connections"
          end
          reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)
          assert !reserved_thread_ids.has_key?( Thread.current.object_id ), "thread should not be in reserved connections"
        end
        aThread.join

        ActiveRecord::Base.connection_pool.checkin main_thread_conn

        reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)
        assert !reserved_thread_ids.has_key?( aThread.object_id ), "thread should not be in reserved connections"
      end
  
end
