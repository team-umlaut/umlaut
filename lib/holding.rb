class Holding
  attr_accessor :locations, :identifier
  def initialize
    @locations = []
  end
  def find_location(location)
    @locations.each do | loc |
      return loc if loc.name == location
    end
    return nil
  end
  
  def find_item_by_attribute(key, value)
    @locations.each do | loc |
      loc.items.each do | item |
        return if item.instance_variable_get('@'+key) == value
      end
    end
    return nil
  end
end

class HoldingLocation
  attr_accessor :name, :code, :items
  def initialize
    @items = []
  end
end

class HoldingItem
  attr_accessor :identifier, :status_code, :status_date, :status, :call_number, :enumeration, :chron, :year
end