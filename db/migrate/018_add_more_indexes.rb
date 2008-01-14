# Some indexes that really should have been there all along.
class AddMoreIndexes < ActiveRecord::Migration
  def self.up
    add_index :referents, :title
    add_index :referents, [:issn, :year, :volume], :name=>'by_issn'
    add_index :referents, :isbn
    add_index :referents, [:year, :volume], :name=>'by_year'
    add_index :referents, :volume

    add_index :referent_values, :key_name

    add_index :requests, :client_ip_addr
    add_index :requests, :params
  end

  def self.down
    remove_index :referents, :title
    remove_index :referents, :name=>'by_issn'
    remove_index :referents, :isbn
    remove_index :referents, :name=>'by_year'
    remove_index :referents, :volume
    
    remove_index :referent_values, :key_name
    
    remove_index :requests, :client_ip_addr
    remove_index :requests, :params
  end
end
