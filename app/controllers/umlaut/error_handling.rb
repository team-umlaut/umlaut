# logic.
module Umlaut::ErrorHandling
  extend ActiveSupport::Concern

  included do
    # Only custom errors in production
    unless  Rails.application.config.consider_all_requests_local
      # generic catch-all comes first, later ones will take priority
      rescue_from Exception, :with => :handle_general_error
      rescue_from ActiveRecord::RecordNotFound, :with => :handle_404_error
    end
  end

  def handle_general_error(exception)

    log_error_with_context(exception)
    @page_title = "Error!"
    # Only render this if we haven't done anything else
    # e.g. if some other gem may be handling its own errors    
    unless performed?  
      if params[:format] == "html"
        render "error", :status => 500  
      else
        render :text => "Unexpected fatal error, has been logged.", :status => 500
      end
    end
  end
  protected :handle_general_error

  # Just returns a generic 404 page.
  # Uses generic 404 page already stored in public/404.html as rails convention.
  def handle_404_error(exception=nil)
    render :file=>File.join(Rails.root ,"public/404"), :layout=>false, :status=>404
  end
  protected :handle_404_error

  def log_error_with_context(exception, severity = :fatal)
    message = "\n#{exception.class} (#{exception.message}):\n"
    message << "  uri: #{request.fullpath}\n\n"
    message << "  params: #{params.inspect}\n\n"
    message << "  Referer: #{request.referer}\n" if request.referer
    message << "  User-Agent: #{request.user_agent}\n"
    message << "  Client IP: #{request.remote_addr}\n\n"
    message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
    # mysterious :noise param seems to match how default rails does it, so
    # we actually get a backtrace.
    message << "  " << Rails.backtrace_cleaner.clean(exception.backtrace, :noise).join("\n  ")
    logger.send(severity, "#{message}\n\n")
  end
  protected :log_error_with_context
end
