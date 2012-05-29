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
  
  # Unload it so we can redefine it completely
  ActiveRecord::ConnectionAdapters.send(:remove_const, :ConnectionPool)
  
  # Some require's our new definition will need
  require 'thread'
  require 'monitor'
  require 'set'
  require 'active_support/core_ext/module/deprecation'
  
  # And completely redefine ConnectionPool

  class ActiveRecord::ConnectionAdapters::ConnectionPool
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
        
        def num_available
          synchronize do
            @queue.size
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
            raise ActiveRecord::ConnectionTimeoutError if elapsed >= timeout
          end
        ensure
          @num_waiting -= 1
        end
      end

      # Every +frequency+ seconds, the reaper will call +reap+ on +pool+.
      # A reaper instantiated with a nil frequency will never reap the
      # connection pool.
      #
      # Configure the frequency by setting "reaping_frequency" in your
      # database yaml file.
      class Reaper
        attr_reader :pool, :frequency

        def initialize(pool, frequency)
          @pool      = pool
          @frequency = frequency
        end

        def run
          return unless frequency
          Thread.new(frequency, pool) { |t, p|
            while true
              sleep t
              p.reap
            end
          }
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
        @dead_connection_timeout = spec.config[:dead_connection_timeout]
        @reaper  = Reaper.new self, spec.config[:reaping_frequency]
        @reaper.run

        # default max pool size to 5
        @size = (spec.config[:pool] && spec.config[:pool].to_i) || 5

        @connections         = []
        @automatic_reconnect = true

        @available = Queue.new self
      end

      # Hack for tests to be able to add connections.  Do not call outside of tests
      def insert_connection_for_test!(c) #:nodoc:
        synchronize do
          @connections << c
          @available.add c
        end
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

      # clear_stale_cached imp from Rails 3.2, still using Threads. 
      # Yes, we've created a monster. 
      # Return any checked-out connections back to the pool by threads that
      # are no longer alive.
      def clear_stale_cached_connections!
        keys = @reserved_connections.keys - Thread.list.find_all { |t|
          t.alive?
        }.map { |thread| thread.object_id }
        keys.each do |key|
          conn = @reserved_connections[key]
          ActiveSupport::Deprecation.warn(<<-eowarn) if conn.in_use?
Database connections will not be closed automatically, please close your
database connection at the end of the thread by calling `close` on your
connection.  For example: ActiveRecord::Base.connection.close
          eowarn
          checkin conn
          @reserved_connections.delete(key)
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
      # - PoolFullError: no connection can be obtained from the pool.
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

      # Removes dead connections from the pool.  A dead connection can occur
      # if a programmer forgets to close a connection at the end of a thread
      # or a thread dies unexpectedly.
      def reap
        synchronize do
          stale = Time.now - @dead_connection_timeout
          connections.dup.each do |conn|
            remove conn if conn.in_use? && stale > conn.last_use && !conn.active?
          end
        end
      end

      private

      # Acquire a connection by one of 1) immediately removing one
      # from the queue of available connections, 2) creating a new
      # connection if the pool is not at capacity, 3) waiting on the
      # queue for a connection to become available.
      #
      # Raises:
      # - PoolFullError if a connection could not be acquired (FIXME:
      #   why not ConnectionTimeoutError?
      def acquire_connection
        if conn = @available.poll
          conn
        elsif @connections.size < @size
          checkout_new_connection
        else
          
          
          t0 = Time.now
          
          Rails.logger.info("POLLED_CHECKOUT: num avail: #{num_available}")
          begin
            @available.poll(@checkout_timeout)
          rescue ActiveRecord::ConnectionTimeoutError
            msg = 'could not obtain a database connection within %0.3f seconds (waited %0.3f seconds)' %
              [@checkout_timeout, Time.now - t0]
            raise ActiveRecord::ConnectionTimeoutError, msg
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
  

