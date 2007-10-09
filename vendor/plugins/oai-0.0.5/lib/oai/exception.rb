module OAI

  # Standard error responses for problems serving OAI content.  These
  # messages will be wrapped in an XML response to the client.

  class Exception < RuntimeError
    attr_reader :code

    def initialize(message, code = nil)
      super(message)
      @code = code
    end
  end

  class ArgumentException < Exception
    def initialize()
      super('The request includes ' \
      'illegal arguments, is missing required arguments, includes a ' \
      'repeated argument, or values for arguments have an illegal syntax.',
      'badArgument')
    end
  end

  class VerbException < Exception
    def initialize()
      super('Value of the verb argument is not a legal OAI-PMH '\
      'verb, the verb argument is missing, or the verb argument is repeated.',
      'badVerb')
    end
  end

  class FormatException < Exception
    def initialize()
      super('The metadata format identified by '\
        'the value given for the metadataPrefix argument is not supported '\
        'by the item or by the repository.', 'cannotDisseminateFormat')
    end
  end

  class IdException < Exception
    def initialize()
      super('The value of the identifier argument is '\
        'unknown or illegal in this repository.', 'idDoesNotExist')
    end
  end

  class NoMatchException < Exception
    def initialize()
      super('The combination of the values of the from, '\
      'until, set and metadataPrefix arguments results in an empty list.',
      'noRecordsMatch')
    end
  end

  class MetadataFormatException < Exception
    def initialize()
      super('There are no metadata formats available '\
        'for the specified item.', 'noMetadataFormats')
    end
  end

  class SetException < Exception
    def initialize()
      super('This repository does not support sets.', 'noSetHierarchy')
    end
  end

  class ResumptionTokenException < Exception
    def initialize()
      super('The value of the resumptionToken argument is invalid or expired.',
        'badResumptionToken')
    end
  end

end