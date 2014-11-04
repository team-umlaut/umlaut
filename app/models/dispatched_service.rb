class DispatchedService < ActiveRecord::Base
  belongs_to :request
  
  # Serialized hash of exception info. 
  serialize :exception_info
  
  # Statuses for status column
  # Still executing, has started  
  InProgress = 'in_progress'
  # Queued up, not yet started. Generally used for background services.
  Queued = 'queued'
  # Complete, succesful. May or may not have produced responses, but
  # completed succesfully either way. 
  Successful = 'successful'
  # Failed, and do not advise trying again. 
  FailedFatal = 'failed_fatal' # Complete, failed,
  # Failed, but it might be worth trying again.
  FailedTemporary = 'failed_temporary'
 
 
  def service=(service)
    self.service_id = service.service_id
  end
  # instantiates a new service object that represents the service
  # that dispatched. 
  def service
    @service ||= ServiceStore.instantiate_service!( self.service_id, request )
  end

  # Calls service.service_type_generated, but cautious of service_id
  # that is no longer in the ServiceStore
  #
  # Note, this means all service types that could possibly be generated
  # by this service, not those that actually have been
  def can_generate_service_types
    if ServiceStore.service_definition_for( self.service_id ) 
      service.service_types_generated
    else
      []
    end
  end

  # For old-time's sake, true can be used for Succesful
  # and false can be used for FailedTemporary (that keeps
  # previous semantics for false intact). 
  def status=(a_status)
    a_status = FailedTemporary if a_status.kind_of?(FalseClass)
    a_status = Successful if a_status.kind_of?(TrueClass)

    # NO: @status = a_status
    # Instead, this is how you 'override' an AR attribute:
    write_attribute(:status, a_status)
  end

  # Will silently refuse to over-write an existing stored exception. 
  def store_exception(a_exc)
      return if a_exc.nil? || ! self.exception_info.nil?
      # Just yaml'izing the exception doesn't keep the backtrace, which is
      # what we wanted. Doh!
      e_hash = Hash.new
      e_hash[:class_name] = a_exc.class.name
      e_hash[:message] = a_exc.message
      e_hash[:backtrace] = a_exc.backtrace
      
      write_attribute(:exception_info, e_hash)
  end

  def completed?
    return (self.status != InProgress) && (self.status != Queued)
  end

  def failed?
    return (self.status == FailedTemporary) || (self.status == FailedFatal)
  end
end
