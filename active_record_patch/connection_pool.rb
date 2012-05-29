######################
#
#  ActiveRecord's ConnectionPool in Rails 3.2.3 allows threads to 'steal'
#  connections from each other, so some threads get starved out. 
#  This monkey patch uses an implementation from https://github.com/rails/rails/pull/6492
#  that ensures 'fair' queue in ConnectionPool. 
#
#  Can be removed if/when we are on an AR that incorporates above patch
#  or equivalent. 
# 
#  This file referenced from an initializer in our main engine
#  class, that loads it to monkey patch AR.
#
##########################

# give a backdoor to disable this patch
unless ENV["NO_AR_PATCH"]
  
  # make sure it's there so we can monkey patch
  require 'active_record'
  ActiveRecord::ConnectionAdapters::ConnectionPool 
  
  
  # Some require's our new definition will need
  require 'thread'
  require 'monitor'
  require 'set'
  require 'active_support/core_ext/module/deprecation'
  
  
  
  # And monkey patch
  module ActiveRecord
  
  
    module ConnectionAdapters
      # Connection pool base class for managing Active Record database
      # connections.
      #
      # == Introduction
      #
      # A connection pool synchronizes thread access to a limited number of
      # database connections. The basic idea is that each thread checks out a
      # database connection from the pool, uses that connection, and checks the
      # connection back in. ConnectionPool is completely thread-safe, and will
      # ensure that a connection cannot be used by two threads at the same time,
      # as long as ConnectionPool's contract is correctly followed. It will also
      # handle cases in which there are more threads than connections: if all
      # connections have been checked out, and a thread tries to checkout a
      # connection anyway, then ConnectionPool will wait until some other thread
      # has checked in a connection.
      #
      # == Obtaining (checking out) a connection
      #
      # Connections can be obtained and used from a connection pool in several
      # ways:
      #
      # 1. Simply use ActiveRecord::Base.connection as with Active Record 2.1 and
      #    earlier (pre-connection-pooling). Eventually, when you're done with
      #    the connection(s) and wish it to be returned to the pool, you call
      #    ActiveRecord::Base.clear_active_connections!. This will be the
      #    default behavior for Active Record when used in conjunction with
      #    Action Pack's request handling cycle.
      # 2. Manually check out a connection from the pool with
      #    ActiveRecord::Base.connection_pool.checkout. You are responsible for
      #    returning this connection to the pool when finished by calling
      #    ActiveRecord::Base.connection_pool.checkin(connection).
      # 3. Use ActiveRecord::Base.connection_pool.with_connection(&block), which
      #    obtains a connection, yields it as the sole argument to the block,
      #    and returns it to the pool after the block completes.
      #
      # Connections in the pool are actually AbstractAdapter objects (or objects
      # compatible with AbstractAdapter's interface).
      #
      # == Options
      #
      # There are several connection-pooling-related options that you can add to
      # your database connection configuration:
      #
      # * +pool+: number indicating size of connection pool (default 5)
      # * +checkout_timeout+: number of seconds to block and wait for a connection
      #   before giving up and raising a timeout error (default 5 seconds).
      # * +reaping_frequency+: frequency in seconds to periodically run the
      #   Reaper, which attempts to find and close dead connections, which can
      #   occur if a programmer forgets to close a connection at the end of a
      #   thread or a thread dies unexpectedly. (Default nil, which means don't
      #   run the Reaper).
      # * +dead_connection_timeout+: number of seconds from last checkout
      #   after which the Reaper will consider a connection reapable. (default
      #   5 seconds).
      class ConnectionPool
        # Threadsafe, fair, FIFO queue.  Meant to be used by ConnectionPool
        # with which it shares a Monitor.  But could be a generic Queue.
        #
        # The Queue in stdlib's 'thread' could replace this class except
        # stdlib's doesn't support waiting with a timeout.
        class Queue
          def initialize(lock = Monitor.new)
            @lock = lock
            @cond = @lock.new_cond
            @num_waiting = 0
            @queue = []
          end
  
          # Test if any threads are currently waiting on the queue.
          def any_waiting?
            synchronize do
              @num_waiting > 0
            end
          end
  
          # Return the number of threads currently waiting on this
          # queue.
          def num_waiting
            synchronize do
              @num_waiting
            end
          end
  
          # Add +element+ to the queue.  Never blocks.
          def add(element)
            synchronize do
              @queue.push element
              @cond.signal
            end
          end
  
          # If +element+ is in the queue, remove and return it, or nil.
          def delete(element)
            synchronize do
              @queue.delete(element)
            end
          end
  
          # Remove all elements from the queue.
          def clear
            synchronize do
              @queue.clear
            end
          end
  
          # Remove the head of the queue.
          #
          # If +timeout+ is not given, remove and return the head the
          # queue if the number of available elements is strictly
          # greater than the number of threads currently waiting (that
          # is, don't jump ahead in line).  Otherwise, return nil.
          #
          # If +timeout+ is given, block if it there is no element
          # available, waiting up to +timeout+ seconds for an element to
          # become available.
          #
          # Raises:
          # - ConnectionTimeoutError if +timeout+ is given and no element
          # becomes available after +timeout+ seconds,
          def poll(timeout = nil)
            synchronize do
              if timeout
                no_wait_poll || wait_poll(timeout)
              else
                no_wait_poll
              end
            end
          end
  
          private
  
          def synchronize(&block)
            @lock.synchronize(&block)
          end
  
          # Test if the queue currently contains any elements.
          def any?
            !@queue.empty?
          end
  
          # A thread can remove an element from the queue without
          # waiting if an only if the number of currently available
          # connections is strictly greater than the number of waiting
          # threads.
          def can_remove_no_wait?
            @queue.size > @num_waiting
          end
  
          # Removes and returns the head of the queue if possible, or nil.
          def remove
            @queue.shift
          end
  
          # Remove and return the head the queue if the number of
          # available elements is strictly greater than the number of
          # threads currently waiting.  Otherwise, return nil.
          def no_wait_poll
            remove if can_remove_no_wait?
          end
  
          # Waits on the queue up to +timeout+ seconds, then removes and
          # returns the head of the queue.
          def wait_poll(timeout)
            @num_waiting += 1
  
            t0 = Time.now
            elapsed = 0
            loop do
              @cond.wait(timeout - elapsed)
  
              return remove if any?
  
              elapsed = Time.now - t0
              raise ConnectionTimeoutError if elapsed >= timeout
            end
          ensure
            @num_waiting -= 1
          end
        end
      
  
        include MonitorMixin
  
        attr_accessor :automatic_reconnect, :checkout_timeout, :dead_connection_timeout
        attr_reader :spec, :connections, :size, :reaper
  
        # Creates a new ConnectionPool object. +spec+ is a ConnectionSpecification
        # object which describes database connection information (e.g. adapter,
        # host name, username, password, etc), as well as the maximum size for
        # this ConnectionPool.
        #
        # The default ConnectionPool maximum size is 5.
        def initialize(spec)
          super()
  
          @spec = spec
  
          # The cache of reserved connections mapped to threads
          @reserved_connections = {}
  
          @checkout_timeout = spec.config[:checkout_timeout] || 5
          
  
          # default max pool size to 5
          @size = (spec.config[:pool] && spec.config[:pool].to_i) || 5
  
          @connections         = []
          @automatic_reconnect = true
  
          @available = Queue.new self
        end
  
  
        # Retrieve the connection associated with the current thread, or call
        # #checkout to obtain one if necessary.
        #
        # #connection can be called any number of times; the connection is
        # held in a hash keyed by the thread id.
        def connection
          synchronize do
            @reserved_connections[current_connection_id] ||= checkout
          end
        end
  
        # Is there an open connection that is being used for the current thread?
        def active_connection?
          synchronize do
            @reserved_connections.fetch(current_connection_id) {
              return false
            }.in_use?
          end
        end
  
        # Signal that the thread is finished with the current connection.
        # #release_connection releases the connection-thread association
        # and returns the connection to the pool.
        def release_connection(with_id = current_connection_id)
          synchronize do
            conn = @reserved_connections.delete(with_id)
            checkin conn if conn
          end
        end
  
        # If a connection already exists yield it to the block. If no connection
        # exists checkout a connection, yield it to the block, and checkin the
        # connection when finished.
        def with_connection
          connection_id = current_connection_id
          fresh_connection = true unless active_connection?
          yield connection
        ensure
          release_connection(connection_id) if fresh_connection
        end
  
        # Returns true if a connection has already been opened.
        def connected?
          synchronize { @connections.any? }
        end
  
        # Disconnects all connections in the pool, and clears the pool.
        def disconnect!
          synchronize do
            @reserved_connections = {}
            @connections.each do |conn|
              checkin conn
              conn.disconnect!
            end
            @connections = []
            @available.clear
          end
        end
  
        # Clears the cache which maps classes.
        def clear_reloadable_connections!
          synchronize do
            @reserved_connections = {}
            @connections.each do |conn|
              checkin conn
              conn.disconnect! if conn.requires_reloading?
            end
            @connections.delete_if do |conn|
              conn.requires_reloading?
            end
            @available.clear
            @connections.each do |conn|
              @available.add conn
            end
          end
        end
  
       
        # Check-out a database connection from the pool, indicating that you want
        # to use it. You should call #checkin when you no longer need this.
        #
        # This is done by either returning and leasing existing connection, or by
        # creating a new connection and leasing it.
        #
        # If all connections are leased and the pool is at capacity (meaning the
        # number of currently leased connections is greater than or equal to the
        # size limit set), an ActiveRecord::PoolFullError exception will be raised.
        #
        # Returns: an AbstractAdapter object.
        #
        # Raises:
        # - ConnectionTimeoutError: no connection can be obtained from the pool.
        def checkout
          synchronize do
            conn = acquire_connection
            conn.lease
            checkout_and_verify(conn)
          end
        end
  
        # Check-in a database connection back into the pool, indicating that you
        # no longer need this connection.
        #
        # +conn+: an AbstractAdapter object, which was obtained by earlier by
        # calling +checkout+ on this pool.
        def checkin(conn)
          synchronize do
            conn.run_callbacks :checkin do
              conn.expire
            end
  
            release conn
  
            @available.add conn
          end
        end
  
        # Remove a connection from the connection pool.  The connection will
        # remain open and active but will no longer be managed by this pool.
        def remove(conn)
          synchronize do
            @connections.delete conn
            @available.delete conn
  
            # FIXME: we might want to store the key on the connection so that removing
            # from the reserved hash will be a little easier.
            release conn
  
            @available.add checkout_new_connection if @available.any_waiting?
          end
        end
  
      
  
        private
  
        # Acquire a connection by one of 1) immediately removing one
        # from the queue of available connections, 2) creating a new
        # connection if the pool is not at capacity, 3) waiting on the
        # queue for a connection to become available.
        #
        # Raises:
        # - ConnectionTimeoutError if a connection could not be acquired (FIXME:
        #   why not ConnectionTimeoutError?
        def acquire_connection
          if conn = @available.poll
            conn
          elsif @connections.size < @size
            checkout_new_connection
          else
            t0 = Time.now
            begin
              @available.poll(@checkout_timeout)
            rescue ConnectionTimeoutError
              msg = 'could not obtain a database connection within %0.3f seconds (waited %0.3f seconds)' %
                [@checkout_timeout, Time.now - t0]
              raise ConnectionTimeoutError, msg
            end
          end
        end
  
        def release(conn)
          thread_id = if @reserved_connections[current_connection_id] == conn
            current_connection_id
          else
            @reserved_connections.keys.find { |k|
              @reserved_connections[k] == conn
            }
          end
  
          @reserved_connections.delete thread_id if thread_id
        end
  
        def new_connection
          ActiveRecord::Base.send(spec.adapter_method, spec.config)
        end
  
        def current_connection_id #:nodoc:
          ActiveRecord::Base.connection_id ||= Thread.current.object_id
        end
  
        def checkout_new_connection
          raise ConnectionNotEstablished unless @automatic_reconnect
  
          c = new_connection
          c.pool = self
          @connections << c
          c
        end
  
        def checkout_and_verify(c)
          c.run_callbacks :checkout do
            c.verify!
          end
          c
        end
      end
  
     
    end
  end
  
end  
  

