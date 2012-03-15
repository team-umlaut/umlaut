# NOTE:  THIS NEEDS TO BE REMOVED WHEN RAILS IS FIXED! 
# We expect it will be fixed in rails 3.2.3 (and broken again in 4, sorry)
# We require at least 3.2.2, so patch only if we're 3.2.2

if Rails.version == "3.2.2" 


  class ActiveRecord::ConnectionAdapters::ConnectionPool
    
    ##########################
    # Monkey patch to fix disastrous concurrency bug in 
    # ActiveRecord ConnectionPool#with_concurrency
    #
    # See https://github.com/rails/rails/issues/5330
    ##########################
    
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
    
    
    ###################################
    #
    # Monkey patch to fix bug with threads waiting
    # on connection waking up, not succesfuly getting
    # a connection, and giving up too early. 
    #
    # https://github.com/rails/rails/pull/5422
    #
    # yeah, we got to replace all of #checkout.
    # that's why we only apply this patch in 3.2.2, not
    # in future rails versions. 
    #####################################
    def checkout
        synchronize do
          waited_time = 0

          loop do
            conn = @connections.find { |c| c.lease }

            unless conn
              if @connections.size < @size
                conn = checkout_new_connection
                conn.lease
              end
            end

            if conn
              checkout_and_verify conn
              return conn
            end

            if waited_time >= @timeout
              raise ConnectionTimeoutError, "could not obtain a database connection#{" within #{@timeout} seconds" if @timeout} (waited #{waited_time} seconds). The max pool size is currently #{@size}; consider increasing it."
            end

            # Sometimes our wait can end because a connection is available,
            # but another thread can snatch it up first. If timeout hasn't
            # passed but no connection is avail, looks like that happened --
            # loop and wait again, for the time remaining on our timeout. 
            before_wait = Time.now
            @queue.wait( [@timeout - waited_time, 0].max )
            waited_time += (Time.now - before_wait)

            # Will go away in Rails 4, when we don't clean up
            # after leaked connections automatically anymore. Right now, clean
            # up after we've returned from a 'wait' if it looks like it's
            # needed, then loop and try again. 
            if(active_connections.size >= @connections.size)
              clear_stale_cached_connections!
            end
          end
        end
      end
    
    
    
  end
  
end
