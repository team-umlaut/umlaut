class OpenSearchController < ApplicationController

  def index
    render(:content_type => "application/xml")
  end
end
