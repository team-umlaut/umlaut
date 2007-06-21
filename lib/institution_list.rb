class InstitutionList
  private_class_method :new
  @@institutions = nil
  
  def self.get(name)
    @@institutions = YAML.load_file(RAILS_ROOT+"/config/institutions.yml") unless @@institutions
    return @@institutions[name]
  end  
end