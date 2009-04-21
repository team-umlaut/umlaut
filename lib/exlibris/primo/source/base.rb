module Exlibris::Primo::Source
  #require 'exlibris/primo'
  class Base < Exlibris::Primo::Holding
    attr_accessor :source_base_url, :source_type
    attr_reader :source_url

    def initialize(e=nil)
      super(e)
      @source_base_url = source_config["base_url"] unless source_config.nil?
      @source_type = source_config["type"] unless source_config.nil?
    end
    
    def source_url
      source_base_url
    end
  end
end