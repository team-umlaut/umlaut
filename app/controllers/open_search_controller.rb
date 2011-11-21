class OpenSearchController < ApplicationController
  include UmlautConfigurable
  
  layout false
  
  
  def index
    render(:content_type => "application/xml")
  end
end
