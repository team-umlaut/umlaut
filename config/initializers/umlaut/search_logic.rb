    
    
    # Is your SFX database connection, defined in database.yml under
    # sfx_db and used for A-Z searches, Sfx3 or Sfx4?  Other SearchMethods
    # in addition to SFX direct db may be provided later. 
    AppConfig::Base.az_search_method = SearchMethods::Sfx4
    #AppConfig::Base.az_search_method = SearchMethods::Sfx3  
    
    # When talking directly to the SFX A-Z list database, you may
    # need to set this, if you have multiple A-Z profiles configured
    # and don't want to use the 'default.
    AppConfig::Base.sfx_az_profile = "default"
