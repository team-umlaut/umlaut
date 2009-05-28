
# Only pre-load the data in production
if ( RAILS_ENV == "production")
  start_t = Time.now
  
  # pre-load ServiceTypeValue cache
  ServiceTypeValue.load_values
  
  # Preload Institution and Service definitions from yml. 
  ServiceList.instance.reload
  InstitutionList.instance.reload
  
  RAILS_DEFAULT_LOGGER.debug("sync_umlaut_data loading caches: #{Time.now - start_t}")
end
