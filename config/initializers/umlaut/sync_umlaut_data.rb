
# Only pre-load the data in production
if ( RAILS_ENV == "production")
  start_t = Time.now
  
  # pre-load ServiceTypeValue cache
  begin
    ServiceTypeValue.load_values
  rescue ActiveRecord::ActiveRecordError
     Rails.logger.debug("Could not sync ServiceTypeValues to db. Perhaps schema hasn't been created yet.")
  end
  
  # Preload Institution and Service definitions from yml. 
  ServiceList.instance.reload
  InstitutionList.instance.reload
  
  Rails.logger.debug("sync_umlaut_data loading caches: #{Time.now - start_t}")
end
