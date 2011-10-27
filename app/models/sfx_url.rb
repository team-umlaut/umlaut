# Just an indexed list of URLs extracted from SFX, urls we believe are
# sfx-controlled. Kind of an ugly hack, kind of duplicates the local journal
# index if in use, but we need it to suppress catalog URLs if they duplicate
# what SFX ought to control. 
class SfxUrl < ActiveRecord::Base

  # Pass in a string, we tell you if we think SFX controls this URL--
  # that is, if the SFX KB handles resources at this URL, or not. 
  # It's really just a guess for a bunch of reasons, but best we can
  # do. We just check hostname, which could create false positives.
  # Checking entire URL won't work. 
  # Lots of things in SFX could create false negatives. 
  def self.sfx_controls_url?(url)
    ActiveRecord::Base.connection_pool.with_connection do
      # Does it match any of our supplementary configged strings or regexps?
      AppConfig.param("additional_sfx_controlled_urls", []).each do |test|
        '===' # will match a regexp or equality on a string
        return true if test === url
      end
      
      begin
        uri = URI.parse(url)
      rescue
        # Bad uri in catalog? Fine, we don't know SFX controls it. 
        return false;
      end
      host = uri.host    
      
      # If URI was malformed, just punt and say no.
      return false unless host    
      
      return SfxUrl.find(:all, :conditions => ["url = ?", host]).length > 0
    end
  end
end
