  # Set up what partials and layouts to use for resolution services. 


  # Use a custom resolve menu view, if you really can't configure
  # the existing one satisfactorily. Deprecatd, you should hardly ever
  # need this with the section description feature below. 
  # AppConfig::Base.resolve_view = 'local/my_institution_resolve_index.erb.html'


  # Use custom layouts for your local look and feel
  #AppConfig::Base.resolve_layout = "distribution/jhu_resolve"
  #AppConfig::Base.search_layout = 'distribution/jhu_search'

  # Use custom configuration to turn off the manual entry typo warning
  #AppConfig::Base.display_manually_entered_typo_warning = false

  # Open search results in a new target window.
  #AppConfig::Base.search_result_target_window = "_blank"
  
  # Describe Individual sections of content. Used for rendering Umlaut html
  # page, used for background-updating of Umlaut html page, used for partial
  # html api.
  #
  # This is a list of hashes. Can include recognized keys from SectionRenderer,
  # see documentation there for details.
  #
  # Order of descripton hashes in this list determines order of display
  # on the HTML resolve page.
  #
  # Additional hash values determine where and whether each section is
  # displayed.
  #
  # html_area => can be sybmols: :main, :sidebar, or :resource_info.  Tells the
  #              resolve/index page to include this section in the designated
  #              area. Some sections are called out by ID for inclusion
  #              in the resolve page, eg cover_image. But most need an
  #              html_area key set to be displayed. 
  # bg_update => false, won't be included in bg update. defaults to true.
  # partial_html_api => false, won't be included in partial html api. defaults to true.

  # You can over-ride this list in your local resolve_views.rb. But rather
  # than re-setting the entire list, for forwards compabibility it's best to try
  # to modify the already existing list just enough. 
  # For instance, to swap order of elements in your local initializer,
  # you can use a convenience method in SectionRenderer:
  # eg: SectionRenderer.swap_if_needed!("document_delivery", "holding")
  #   => ensure document_delivery comes _before_ holding, swapping their
  #      places if neccesary. 
 begin
   AppConfig::Base.resolve_sections = 
                           [
                            { :div_id => "cover_image",
                              :partial => "cover_image",
                              :visibility => :responses_exist,
                              :show_heading => false,
                              :show_spinner => false
                            },
                            { :div_id => "search_inside",
                              :html_area => :resource_info,
                              # partial handles it's own visiblity and spinner
                              :partial => "search_inside",                            
                              :show_partial_only => true                      
                            },
                            { :div_id => "fulltext",
                              :section_title => "#{ServiceTypeValue[:fulltext].display_name} via:",
                              :html_area => :main,
                              # we use a custom complete partial for list with 
                              #limit and custom labels for 'can not link direct
                              #to citation''
                              :partial => "fulltext",
                              :show_partial_only => true
                            },
                            { :div_id => "excerpts",
                              :section_prompt => 
                                "A limited preview which may include table of contents, index, and other selected pages.",
                              :html_area => :main,
                              :list_visible_limit => 5,
                              :visibility => :responses_exist,                            
                            },
                            { :div_id => "audio",
                              :section_title =>
                                "#{ServiceTypeValue[:audio].display_name} via",
                              :html_area => :main,
                              :visibility => :responses_exist                            
                            },
                            { :div_id => "holding",
                              :section_title => ServiceTypeValue[:holding].display_name_pluralize,
                              :html_area => :main,
                              :partial => 'holding',
                              :service_type_values =>
                                ["holding","holding_search"],
                            },
                            { :div_id => "document_delivery",
                              :section_title => "Request a copy from Inter-Library Loan",
                              :html_area => :main,
                              :visibility => :responses_exist,
                              :bg_update => false
                            },
                            { :div_id => 'table_of_contents',
                              :html_area => :main,
                              :visibility => :responses_exist
                            },
                            { :div_id => 'abstract',
                              :html_area => :main,
                              :visibility => :responses_exist                          },
                            { :div_id => 'help',
                              :html_area => :sidebar,
                              :bg_update => false,
                              :partial => 'help',
                              :show_heading => false,
                              :show_spinner => false,
                              :visibility => :responses_exist
                            },
                            { :div_id => 'coins',
                              :html_area => :sidebar,
                              :partial=>"coins", 
                              :service_type_values => [], 
                              :show_heading => false, 
                              :show_spinner => false,
                              :bg_update => false,
                              :partial_html_api => false
                            },
                            { :div_id => 'export_citation',
                              :html_area => :sidebar,
                              :visibility => :in_progress,
                              :item_name_plural => "Export tools"
                              },
                            { :div_id => 'related_items',
                              :html_area => :sidebar,
                              :partial => 'related_items',
                              :section_title => "More like this",
                              :item_name_plural => "Related Items",
                              # custom visibility, show it for item-level cites,
                              # or if we actually have some
                              :visibility => lambda do |renderer|
                                 (! renderer.request.title_level_citation?) ||
                                 (! renderer.responses_empty?)
                              end,
                              :service_type_values => ['cited_by', 'similar']},
                            { :div_id => "highlighted_link",
                              :section_title => "See also",
                              :html_area => :sidebar,
                              :visibility => :in_progress,
                              :partial_locals => { :show_source => true }
                            }
                         ]
                      
  
    # Tells the bg updater 
    AppConfig::Base.error_div = { :div_id => 'service_errors',
                                  :partial => 'service_errors'}
rescue ActiveRecord::ActiveRecordError => e
  Rails.logger.warn("Couldn't initiailize resolve_views. Database schema not created yet? #{e.inspect}")
end
