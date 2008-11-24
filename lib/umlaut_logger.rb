# Subclass Rails' BufferedLogger to support a formatter, as per this
# patch: http://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/1307-bufferedlogger-should-support-message-formatting#ticket-1307-2
# If that patch makes it into a future version of rails, we can just use BufferedLogger, not this sub-class. 
class UmlautLogger < ActiveSupport::BufferedLogger
  # set to something where calling 'call' on it will format
  attr_accessor :formatter

  SEV_LABEL = {}
  for severity in Severity.constants
      SEV_LABEL[Severity.const_get(severity)] = severity
  end


  def initialize(log, level=DEBUG)
    super(log, level)
    # The default formatter returns the message unchanged.
    @formatter = lambda { |severity_label, message| message }
  end
  
  def add(severity, message=nil, progname = nil, &block)
      return if @level > severity
      message = (message || (block && block.call) || progname).to_s
      # Format the message.
      # Ensures that the original message is not mutated.
      message = @formatter.call(SEV_LABEL[severity] || severity, "#{message}")
      # If a newline is necessary, then create a new message ending with a newline.
      message = "#{message}\n" unless message[-1] == ?\n
      buffer << message
      auto_flush
      message

  end

end
