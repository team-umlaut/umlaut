class DispatchedService < ActiveRecord::Base
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
  

  belongs_to :request
  def service=(service)
    self.service_id = service.id
  end

  # For old-time's sake, true can be used for Succesful
  # and false can be used for FailedTemporary (that keeps
  # previous semantics for false intact). 
  def status=(a_status)
    a_status = FailedTemporary if a_status.kind_of?(FalseClass)
    a_status = Successful if a_status.kind_of?(TrueClass)

    @status = a_status
  end
end
