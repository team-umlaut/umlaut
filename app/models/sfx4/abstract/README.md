SFX4 Abstract AZ Models
---

The modules in `Sfx4::Abstract` represent SFX4 A-Z tables for connecting to local SFX instances.
They are abstracted out so that the Umlaut implementer can include the relevant module for the particular instance of the model.

In addition to representing the AZ tables, individual modules implement specific functionality.

  - `Sfx4::Abstract::Base` implements functionality for searching SFX for "SFX controlled" URLs.
  - `Sfx4::Abstract::AzTitle` implements Sunspot functionality for indexing SFX records in Solr.

Examples are the classes in the `Sfx4::Local` module.

    module Sfx4
      module Local
        class Base < ActiveRecord::Base
          self.establish_connection :sfx_db
          # ActiveRecord likes it when we tell it this is an abstract
          # class only. 
          self.abstract_class = true 
          extend Sfx4::Abstract::Base

          # All SFX things are read-only!
          def readonly?() 
            return true
          end
        end
      end
    end

    module Sfx4
      module Local
        class AzTitle < Sfx4::Local::Base
          include Sfx4::Abstract::AzTitle
        end
      end
    end

If your Umlaut implementation needs to point to an additional SFX DB (e.g. for consortial reasons), you can create another Sfx4 module
that holds your classes for the additional SFX DB (as long as the configuration is specified in database.yml).

    # Current file: /app/model/sfx4/additional_instance/base.rb
    module Sfx4
      module AdditionalInstance
        class Base < ActiveRecord::Base
          self.establish_connection :sfx_db_additional_instance
          # ActiveRecord likes it when we tell it this is an abstract
          # class only. 
          self.abstract_class = true 
          extend Sfx4::Abstract::Base

          # All SFX things are read-only!
          def readonly?() 
            return true
          end
        end
      end
    end

    # Current file: /app/model/sfx4/additional_instance/az_title.rb
    module Sfx4
      module AdditionalInstance
        class AzTitle < Sfx4::AdditionalInstance::Base
          include Sfx4::Abstract::AzTitle
        end
      end
    end
    