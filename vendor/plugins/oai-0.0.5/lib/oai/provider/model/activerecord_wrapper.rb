require 'active_record'

module OAI::Provider
  # = OAI::Provider::ActiveRecordWrapper
  # 
  # This class wraps an ActiveRecord model and delegates all of the record
  # selection/retrieval to the AR model.  It accepts options for specifying
  # the update timestamp field, a timeout, and a limit.  The limit option 
  # is used for doing pagination with resumption tokens.  The
  # expiration timeout is ignored, since all necessary information is
  # encoded in the token.
  #
  class ActiveRecordWrapper < Model
    
    attr_reader :model, :timestamp_field
    
    def initialize(model, options={})
      @model = model
      @timestamp_field = options.delete(:timestamp_field) || 'updated_at'
      @limit = options.delete(:limit)
      
      unless options.empty?
        raise ArgumentException.new(
          "Unsupported options [#{options.join(', ')}]"
        )
      end
    end
    
    def earliest
      model.find(:first, 
        :order => "#{timestamp_field} asc").send(timestamp_field)
    end
    
    def latest
      model.find(:first, 
        :order => "#{timestamp_field} desc").send(timestamp_field)
    end

    # A model class is expected to provide a method Model.sets that
    # returns all the sets the model supports.  See the 
    # activerecord_provider tests for an example.   
    def sets
      model.sets if model.respond_to?(:sets)
    end
    
    def find(selector, options={})
      return next_set(options[:resumption_token]) if options[:resumption_token]
      conditions = sql_conditions(options)
      
      if :all == selector
        total = model.count(:id, :conditions => conditions)
        if @limit && total > @limit
          select_partial(ResumptionToken.new(options.merge({:last => 0})))
        else
          model.find(:all, :conditions => conditions)
        end
      else
        model.find(selector, :conditions => conditions)
      end
    end
    
    def deleted?(record)
      if record.respond_to?(:deleted_at)
        return record.deleted_at
      elsif record.respond_to?(:deleted)
        return record.deleted
      end
      false
    end    
    
    protected
    
    # Request the next set in this sequence.
    def next_set(token_string)
      raise OAI::ResumptionTokenException.new unless @limit
    
      token = ResumptionToken.parse(token_string)
      total = model.count(:id, :conditions => token_conditions(token))
    
      if @limit < total
        select_partial(token)
      else # end of result set
        model.find(:all, 
          :conditions => token_conditions(token), 
          :limit => @limit, :order => "#{model.primary_key} asc")
      end
    end
    
    # select a subset of the result set, and return it with a
    # resumption token to get the next subset
    def select_partial(token)
      records = model.find(:all, 
        :conditions => token_conditions(token),
        :limit => @limit, 
        :order => "#{model.primary_key} asc")

      raise OAI::ResumptionTokenException.new unless records

      offset = records.last.send(model.primary_key.to_sym)
      
      PartialResult.new(records, token.next(offset))
    end
    
    # build a sql conditions statement from the content
    # of a resumption token.  It is very important not to
    # miss any changes as records may change scope as the
    # harvest is in progress.  To avoid loosing any changes
    # the last 'id' of the previous set is used as the 
    # filter to the next set.
    def token_conditions(token)
      last = token.last
      sql = sql_conditions token.to_conditions_hash
      
      return sql if 0 == last
      # Now add last id constraint
      sql[0] << " AND #{model.primary_key} > ?"
      sql << last
      
      return sql
    end
    
    # build a sql conditions statement from an OAI options hash
    def sql_conditions(opts)
      sql = []
      sql << "#{timestamp_field} >= ?" << "#{timestamp_field} <= ?" 
      sql << "set = ?" if opts[:set]

      esc_values = [sql.join(" AND ")]
      esc_values << opts[:from].localtime << opts[:until].localtime
      esc_values << opts[:set] if opts[:set]
      
      return esc_values
    end
    
  end
end
