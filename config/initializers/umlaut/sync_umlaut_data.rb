   # sync institutions.yml to db if needed by timestamp.
    begin
      Institution.sync_institutions
      ServiceTypeValue.load_values
    rescue Exception => e
      # If we're just starting out and don't have a db yet, we can't run
      # this, oh well.
      RAILS_DEFAULT_LOGGER.warn("Couldn't check institutions and service_type_values for syncing: #{e}")
    end

