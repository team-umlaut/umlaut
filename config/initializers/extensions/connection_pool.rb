# Monkey patch to fix disastrous concurrency bug in 
# ActiveRecord ConnectionPool#with_concurrency
#
# See https://github.com/rails/rails/issues/5330
#
# Verified bug needs fixing in rails 3.2.2
#
# NOTE:  THIS NEEDS TO BE REMOVED WHEN RAILS IS FIXED! Have a rails version
# after 3.2.2? Check to see if it's fixed in rails already.  

# Note we try to check to make sure rails isn't already patched, but
# there's no guarantee this will work, rails may fix the bug
# without adding a "#current_connection?" method like we do!
unless ActiveRecord::ConnectionAdapters::ConnectionPool.instance_methods.include?(:current_connection?)

  class ActiveRecord::ConnectionAdapters::ConnectionPool
    
    # New method we're adding viz a viz rails 3.2.2
    # Check to see if there is an active connection for
    # current_connection_id, that is by default the current
    # thread.
    def current_connection?
      @reserved_connections.has_key?(current_connection_id)
    end
    
    # Redefine with_connection viz a viz rails 3.2.2 to
    # properly check back in connections. 
    # If a connection already exists yield it to the block. If no connection
    # exists checkout a connection, yield it to the block, and checkin the
    # connection when finished.
    def with_connection
      connection_id = current_connection_id
      fresh_connection = true unless current_connection?
      yield connection
    ensure
      release_connection(connection_id) if fresh_connection
    end
    
  end
  
end
