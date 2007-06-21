class Institution < ActiveRecord::Base
  has_and_belongs_to_many :users
    
  def display_name
    self.load_configuration unless @display_name
    return @display_name
  end

  def display_name
    self.load_configuration unless @postal_code
    return @postal_code
  end
  
  def oclc_symbol
    self.load_configuration unless @oclc_symbol
    return @oclc_symbol
  end

  def services
    self.load_configuration unless @services
    return @services
  end    
  protected
  def load_configuration
    unless i = InstitutionList.get(self.name)
      i = YAML.load(self.configuration)
    end
    @display_name = i["display_name"]
    @postal_code = i["postal_code"]
    @oclc_symbol = i["oclc_symbol"]
    self.load_services(i["services"]) if i["services"]
  end
  def load_services(svc_list)
    @services = []
    svc_list.each do | svc |
      @services << ServiceList.get(svc)
    end
  end
end
