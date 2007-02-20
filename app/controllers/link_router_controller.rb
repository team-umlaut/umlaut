class LinkRouterController < ApplicationController
  require 'cgi'
  def index
    redirect_to CGI.unescape(@params[:url]) 
    history = History.find_by_session_id_and_request_id(session.session_id, @params[:id])
    clickthrough = Clickthrough.new
    clickthrough.target_source = @params[:source]
    clickthrough.target_source_id = @params[:source_id]
    clickthrough.service = @params[:service]
    clickthrough.url = CGI.unescape(@params[:url])
    clickthrough.history_id = history.id
    clickthrough.save
  end
end
