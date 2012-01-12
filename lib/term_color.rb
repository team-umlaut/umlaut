# Just some methods for outputting colorized text to a terminal
# with ansi codes, cribbed from rails. 

module TermColor
  mattr_accessor :colorize_logging
  self.colorize_logging = Rails.application.config.colorize_logging
  
    # Embed in a String to clear all previous ANSI sequences.
    CLEAR   = "\e[0m"
    BOLD    = "\e[1m"

    # Colors
    BLACK   = "\e[30m"
    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"
    WHITE   = "\e[37m"
  
    # Set color by using a string or one of the defined constants. If a third
    # option is set to true, it also adds bold to the string. This is based
    # on the Highline implementation and will automatically append CLEAR to the
    # end of the returned String.
    #
    def self.color(text, color, bold=false)
      #return text unless colorize_logging
      color = self.const_get(color.to_s.upcase) if color.is_a?(Symbol)
      bold  = bold ? BOLD : ""
      "#{bold}#{color}#{text}#{CLEAR}"
    end
  
end
