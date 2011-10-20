    # Referent filters. Sort of like SFX source parsers.
    # hash, key is regexp to match a sid, value is filter object
    # (see lib/referent_filters )

    AppConfig::Base.referent_filters = {/.*/ => DissertationCatch.new  }
