# Extend ActiveRecordModel to support sets
class SetModel < OAI::Provider::ActiveRecordWrapper
  
  # Return all available sets
  def sets
    DCSet.find(:all)
  end

  # Scope the find to a set relation if we get a set in the options    
  def find(selector, opts={})
    if opts[:set]
      set = DCSet.find_by_spec(opts.delete(:set))
      conditions = sql_conditions(opts)

      if :all == selector
        set.dc_fields.find(selector, :conditions => conditions)
      else
        set.dc_fields.find(selector, :conditions => conditions)
      end
    else
      if :all == selector
        model.find(selector, :conditions => sql_conditions(opts))
      else
        model.find(selector, :conditions => sql_conditions(opts))
      end
    end
  end
        
end

class ARSetProvider < OAI::Provider::Base
  repository_name 'ActiveRecord Set Based Provider'
  repository_url 'http://localhost'
  record_prefix = 'oai:test'
  source_model SetModel.new(DCField)
end