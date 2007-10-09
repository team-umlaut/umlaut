module OAI::Provider
  # = OAI::Provider::Model
  #
  # Model implementers should subclass OAI::Provider::Model and override 
  # Model#earliest, Model#latest, and Model#find.  Optionally Model#sets and
  # Model#deleted? can be used to support sets and record deletions.  It 
  # is also the responsibility of the model implementer to account for 
  # resumption tokens if support is required.  Models that don't support 
  # resumption tokens should raise an exception if a limit is requested     
  # during initialization.
  #
  # earliest - should return the earliest update time in the repository.
  # latest - should return the most recent update time in the repository.
  # sets - should return an array of sets supported by the repository.
  # deleted? - individual records returned should respond true or false
  # when sent the deleted? message.
  #
  # == Resumption Tokens
  #
  # For examples of using resumption tokens see the
  # ActiveRecordWrapper, and ActiveRecordCachingWrapper classes.
  #
  # There are several helper models for dealing with resumption tokens please
  # see the ResumptionToken class for more details.
  #

  class Model
    attr_reader :timestamp_field
    
    def initialize(limit = nil, timestamp_field = 'updated_at')
      @limit = limit
      @timestamp_field = timestamp_field
    end

    # should return the earliest timestamp available from this model.
    def earliest
      raise NotImplementedError.new
    end
    
    # should return the latest timestamp available from this model.
    def latest
      raise NotImplementedError.new
    end
    
    def sets
      nil
    end
  
    # find is the core method of a model, it returns records from the model
    # bases on the parameters passed in.
    #
    # <tt>selector</tt> can be a singular id, or the symbol :all
    # <tt>options</tt> is a hash of options to be used to constrain the query.
    #
    # Valid options:
    # * :from => earliest timestamp to be included in the results
    # * :until => latest timestamp to be included in the results
    # * :set => the set from which to retrieve the results
    # * :metadata_prefix => type of metadata requested (this may be useful if 
    #                       not all records are available in all formats)
    def find(selector, options={})
      raise NotImplementedError.new
    end
    
    def deleted?
      false
    end
    
  end
  
end
