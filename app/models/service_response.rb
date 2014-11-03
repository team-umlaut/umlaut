=begin rdoc

A ServiceResponse represents a single piece of data or content generated in response to a request. 
For instance, a full text link, a 'see also' link, a cover image, a library holding, or an
available 'search inside' service. 

ServiceResponses were generated *for* to a particular request (`#request`), were
generated *by* a particular service (`#service_id` or `#service`), and 
belong to a *category or type* such as 'fulltext', 'excerpts', or 'search_inside'
(#service_type_value)

A ServiceResponse additionally has a hash of keys and values representing
it's actual payload or content or data. Some of these keys are stored 
individually in database columns of their own, others are stored in
a hash serialized to attribute `service_data` -- ServiceResponse offers
an API so you ordinarily don't need to care which is which; any arbitrary
key/value pairs can be included in a ServiceResponse. 

      service_response.view_data
      #=> A hash of key/value pairs representing the payload

You ordinarily create a ServiceResponse by asking a particular
Umlaut Request to do so:

      umlaut_request.add_service_response(
        :service=>self, 
        :service_type_value => :fulltext
        :display_text => "Some link", 
        :url => "http://example.com"        
      )

There are certain conventional keys (like :display_text and :notes) accross
most response types, and other keys that might be particular to a certain type
or even a certain service. Services can store data in their own custom keys
for their own use. See "Conventional Keys" below for documentation on Umlaut
standard naming. 

== Transformation of view data on display: transform_view_data and response_url

When a ServiceResponse is created, it's initialized with some key/value
service_data that is stored in the database. 

However, there are also features in place letting a Service filter or transform
this key/value data at the point of display or use. 

If a Service implements a method `transform_view_data(hash)`, then this method
will be called at the point of view_data use (possibly multiple times). You can
modify the hash passsed in, or even replace it entirelyl, just return a new hash.

    def transform_view_data(hash)
      if hash[:add_some_notes]
         hash[:display_text] = some_helper_method( params[:something])
      end

      return hash
    end

This can be especially useful for internationalization (i18n), please see Umlaut
wiki at https://github.com/team-umlaut/umlaut/wiki/Localization#services-and-their-generated-serviceresponses

Similarly, instead of calculating the URL at the point of recording a ServiceResponse,
you can implement a method `response_url` that will be called when a user clicks
on a ServiceResponse, and can return a URL to redirect the user too. 

This is useful if the URL is expensive to calculate; or if you want to log or report
something on click; or if the URL needs user-input to be calculated (eg search_inside deep link)

    def response_url(service_response, submitted_params)
       return "http://books.google.com/#{service_response.view_data[:book_id]?query=submitted_params[:q]"
    end

== View Display of ServiceResponse

The resolve menu View expects a Hash (or Hash-like) object with certain conventional keys, 
to display a particular ServiceResponse. You can provide code in your Service to translate a
 ServiceResponse to a Hash. But you often don't need to, you can use the proxy object returned by 
 #data_values instead, which provides hash-like access to all arbitrary key/values stored in ServiceResponse. 
 If the Service stores properties in there using conventional keys (see below), no further translation is needed.

However, if you need to do further translation you can implement methods on the Service, of the form: "to_[service type string](response)", for instance "to_fulltext". Umlaut will give it a ServiceResponse object, method should return a hash (or hash-like obj).  Service can also implement a method response_to_view_data(response), as a 'default' translation. This mechanism of various possible 'translations' is implemented by Service#view_data_from_service_type.

== Url generation

At the point the user clicks on a ServiceResponse, Umlaut will attempt to find a url for the ServiceResponse, 
by calling response_url(response) on the relevant Service. The default 
implementation in service.rb just returns service_response['url'], so the easiest way 
to do this is just to put the url in service_response['url'].  However, your Service can over-ride 
this method to provide it's own implementation to generate to generate the url on demand in any way it wants. 
 If it does this, technically service_response['url'] doesn't need to include anything. But if you have a URL, 
 you may still want to put it there, for Umlaut to use in guessing something about the destination, 
 for de-duplication and possibly other future purposes.  

== Note on ServiceType join table. 

ServiceResponse is connected to a Request via the ServiceType join table. This is mostly
for legacy reasons, currently unused -- normally a ServiceResponse is attached to one
and only one Request. 

The architecture would allows a ServiceResponse to be tied to multiple requests, 
perhaps to support some kind of cacheing re-use in the future. But at present, the code 
doesn't do this, a ServiceResponse will really only be related to one request. However, a 
ServiceResponse can be related to a single Request more than once--once per each type of 
service response. ServiceType is really a three way join, representing a ServiceResponse, 
attached to a particular Request, with a particular ServiceTypeValue.  

= Conventional keys

 Absolute minimum: 
 [:display_text]   Text that will be used 

 Basic set (used by fulltext and often others)
 [:display_text]
 [:notes]          (newlines converted to <br>)
 [:coverage]
 [:authentication]
 [:match_reliability] => One of MatchExact or MatchUnsure (maybe more later), for whether there's a chance this is an alternate Edition or the wrong work entirely. These are fuzzy of neccisity -- if it MIGHT be an alt edition, use MatchAltEdition even if you can't be sure it's NOT an exact match. 
 :edition_str => String statement of edition or work to let the user disambiguate and see if it's what they want. Can be taken for instance from Marc 260. Generally only displayed when match_reliabilty is not MatchExact. If no value, Umlaut treats as MatchExact.

== Full text specific
These are applicable only when the incoming OpenURL is an article-level citation. Umlaut uses Request#title_level_citation? to estimate this.

  [:coverage_checked]  boolean, default true.  False for links from, eg, the catalog, where we weren't able to pre-check if the particular citation is included at this link.
  [:can_link_to_article] boolean, default true. False if the links is _known_ not to deliver user to actual article requested, but just to a title-level page. Even though SFX links sometimes incorrectly do this, they are still not set to false here.  
  
== Coverage dates
Generally only for fulltext. Right now only supplied by SFX. 

  [:coverage_begin_date]  Ruby Date object representing start of coverage
  [:coverage_end_date]  Ruby Date object representing end of coverage
 
== highlighted_link (see also)
 [:source]   (optional, otherwise service's display_name is used)

== Holdings set adds:
 [:source_name]
 [:call_number]
 [:status]
 [:request_url]     a url to request the item. optional. 
 [:coverage_array] (Array of coverage strings.)
 [:due_date]
 [:collection_str]
 [:location_str]

== search_inside
 Has no additional conventional keys, but when calling it's url handling functionality, send it a url param query= with the users query. In the API, this means using the umlaut_passthrough_url, but adding a url parameter query on to it. This will redirect to the search results. 

== Cover images:
 [:display_text] set to desired alt text
 [:url]    src url to img
 [:size]  => 'small', 'medium', 'large' or 'extra-large'. Also set in :key

== Anything from amazon:
 [:asin]

== Abstracts/Tocs:
   Can be a link to, or actual content. Either way, should be set
   up to link to source of content if possible. Basic set, plus:
   [:content]           actual content, if available.
   [:content_html_safe] Set to true if content includes html which should be
                        passed through un-escaped. Service is responsible
                        for making sure the HTML is safe from injection
                        attacks (injection attacks from vendor API's? Why not?).
                        ActionView::Helpers::SanitizeHelper's #sanitize
                        method can convenient. 

=end
require 'truncate_to_db_limit'
class ServiceResponse < ActiveRecord::Base  
  @@built_in_fields = [:display_text, :url, :notes, :response_key, :value_string, :value_alt_string, :value_text, :id]
  belongs_to :request
  serialize :service_data  
  # This value is not stored in db, but is set temporarily so
  # the http request params can easily be passed around with a response
  # object.
  attr_accessor :http_request_params

  include TruncateToDbLimit
  truncate_to_db_limit :display_text

  # Constants for 'match_reliability' value.
  MatchExact = 'exact'
  MatchUnsure = 'unsure'
  #MatchAltEdition = 'edition'
  #MatchAltWork = 'work'

  def initialize(*args)
    super
    self.service_data = {} unless self.service_data
  end
  
  # Create from a hash of key/values, where some keys
  # may be direct iVars, some may end up serialized in service_data, 
  # you don't have to care, it will do the right thing. 
  def self.create_from_hash(hash)
    r = ServiceResponse.new
    r.take_key_values(hash)
    return r
  end

  # Instantiates and returns a new Service associated with this response.
  def service
    @service ||= ServiceStore.instantiate_service!( self.service_id, nil )
  end
    
  def service_data
    # Fix weird-ass char encoding bug with AR serialize and hashes.
    # https://github.com/rails/rails/issues/6538
    data = super
    if data.kind_of? Hash
      data.values.each {|v| v.force_encoding "UTF-8"  if v.respond_to? :force_encoding  }
    end
    return data
  end
  
    # Should take a ServiceTypeValue object, or symbol name of
  # ServiceTypeValue object. 
  def service_type_value=(value)
    value = ServiceTypeValue[value] unless value.kind_of?(ServiceTypeValue)        
    self.service_type_value_name = value.name   
  end
  def service_type_value
    ServiceTypeValue[self.service_type_value_name]
  end
  
  

  def take_key_values(hash)    
    hash.each_pair do |key, value|
      setter = "#{key.to_s}="      
      if ( self.respond_to?(setter))
        self.send(setter, value)
      else
        self.service_data[key] = value
      end
    end
  end


  def view_data    
    unless (@data_values)  
      h = HashWithIndifferentAccess.new
      ServiceResponse.built_in_fields.each do |key|
        h[key] = self.send(key)
      end
      h.merge!(self.service_data.deep_dup)

      # add in service_type_value
      h[:service_type_value] = self.service_type_value_name

      # Handle requested i18n translations
      translate_simple_i18n!(h)

      # Optional additional transformation provided by service?
      if service.respond_to? :transform_view_data
        h = service.transform_view_data(h)
      end

      # Doesn't protect modifying nested structures, but
      # protects from some problems. 
      h.freeze 
      @data_values = h
    end
    return @data_values;
  end
  # old name now duplicate
  alias_method :data_values, :view_data

  def self.built_in_fields
    @@built_in_fields
  end
  
  protected
  # replaces :display_text and :notes with simple i18n key lookups
  # iff :display_text_i18n and :notes_i18n are defined
  #
  # i18n lookups use Service.translate, to use standard scopes for
  # this service. 
  def translate_simple_i18n!(hash)
    if key = hash[:display_text_i18n]
      hash[:display_text] = self.service.translate(key, :default => hash[:display_text])
    end
    if key = hash[:notes_i18n]
      hash[:notes] = self.service.translate(key, :default => hash[:notes])
    end
  end
  
end
