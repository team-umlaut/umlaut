    # Umlaut can theoretically have a local journal title index for search
    # actions (ie citation linker/A-Z list), loaded
    # from SFX or elsewhere. But Hopkins isn't using that functionality,
    # instead doing live lookups to the SFX db. The functionality isn't
    # fully tested or probably fully working right now, but in the future.
    
    AppConfig::Base.use_umlaut_journal_index = false
