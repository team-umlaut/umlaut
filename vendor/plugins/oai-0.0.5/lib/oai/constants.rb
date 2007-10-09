module OAI

  module Const
    # OAI defines six verbs with various allowable options.
    VERBS = {
      'Identify' => [],
      'ListMetadataFormats' => [],
      'ListSets' => [:resumption_token],  # unused currently
      'GetRecord' => [:identifier, :from, :until, :set, :metadata_prefix],
      'ListIdentifiers' => [:from, :until, :set, :metadata_prefix, :resumption_token],
      'ListRecords' => [:from, :until, :set, :metadata_prefix, :resumption_token]
    }.freeze
    
    RESERVED_WORDS = %w{type id}
    
    # Two granularities are supported in OIA-PMH, daily or seconds. 
    module Granularity
      LOW = 'YYYY-MM-DD'
      HIGH = 'YYYY-MM-DDThh:mm:ssZ'
    end
    
    # Repositories can support three different schemes for dealing with deletions.
    # * NO - No deletions allowed
    # * TRANSIENT - Deletions are supported but may not be permanently maintained.
    # * PERSISTENT - Deletions are supported and are permanently maintained.
    module Delete
      NO = :no
      TRANSIENT = :transient
      PERSISTENT = :persistent
    end
        
  end
  
end
