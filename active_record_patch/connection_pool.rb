######################
#
#  Monkey patch to ActiveRecord to prevent 'implicit' checkouts. 
#
#  If you create a thread yourself, if it uses ActiveRecord objects without
#  explicitly checking out a connection, one will still be checked out implicitly.
#  If it is never checked back in with `ActiveRecord::Base.clear_active_connections!`,
#  then it will be leaked. 
#
#  For some uses, we want to avoid being able to do that kind of implicit checkout,
#  force all ActiveRecord use to be via an explicit checkout using with_connection
#  or checkout. 
#
#  With this monkey patch, a thread can call:
#
#      ActiveRecord::Base.forbid_implicit_checkout_for_thread!
#
#  And subsequently, if that thread accidentally tries to do an implicit
#  checkout, an exception will be raised. 
#
#  The exception raised is defined here as ImplicitConnectionForbiddenError < ActiveRecord::ConnectionTimeoutError
#
##########################

module ActiveRecord
  class Base
    class << self
      def forbid_implicit_checkout_for_thread!
        Thread.current[:active_record_forbid_implicit_connections] = true
      end

      def connection_with_forbid_implicit(*args, &block)
        if ( Thread.current[:active_record_forbid_implicit_connections] && 
             ! connection_handler.retrieve_connection_pool(self).active_connection?)

          msg = "Implicit ActiveRecord checkout attempted when Thread :force_explicit_connections set!"

          # I want to make SURE I see this error in test output, even though
          # in some cases my code is swallowing the exception. Unless silenced,
          # probably only in the unit test of this function itself
          if Rails.env.test? && (Thread.current[:ar_implicit_checkout_warning_silenced] != true)
            $stderr.puts msg
          end

          raise ImplicitConnectionForbiddenError.new(msg)
        end
        connection_without_forbid_implicit(*args, &block)
      end    
      alias_method_chain :connection, :forbid_implicit

    end           
  end  
  
  # We're refusing to give a connection when asked for. Same outcome
  # as if the pool timed out on checkout, so let's subclass the exception
  # used for that.   
  class ImplicitConnectionForbiddenError < ActiveRecord::ConnectionTimeoutError ; end

  # Workaround to leaked connections database outage/recovery, 
  # https://github.com/rails/rails/issues/20114
  # Fix expected in 4.2.2, workaround only applies to 4.x, you're on your
  # own for Rails 3.x, upgrade. 
  rails_version = Gem::Version.new(Rails.version)
  if (rails_version >= Gem::Version.new("4.0")) && (rails_version < Gem::Version.new("4.2.2"))
    class ConnectionAdapters::ConnectionPool

      def checkout_and_verify_with_rescue(c)
        checkout_and_verify_without_rescue(c)
      rescue Exception
        remove c
        c.disconnect!

        raise
      end
      alias_method_chain :checkout_and_verify, :rescue

    end  
  end

end

