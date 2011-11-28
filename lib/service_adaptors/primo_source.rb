# == Overview
# PrimoSource is a PrimoService that converts primo_source service types into Primo source holdings.
# This mechanism allows linking to original data sources and expanded holdings information
# based on those sources and can be implemented per source.
# To create a Primo source holding, you first must create a local class representing the source in
# module Exlibris::Primo::Source::Local which extends Exlibris::Primo::Holding.
# Two methods are then available for overriding:
#     :expand -   expand holdings that may have been collapsed into a single availlibrary element 
#                 in Primo based on information from the source
#                 default: [self]
#     :dedup? -   if this data source contain duplicate holdings that need to be deduped, set to true
#                 default: false
# The following properties can also be overridden in the initialize method
#     :record_id, :source_id, :original_source_id, :source_record_id,
#     :availlibrary, :institution_code, :institution, :library_code, :library,
#     :status_code, :status, :id_one, :id_two, :origin, :display_type, :coverage, :notes,
#     :url, :request_url, :match_reliability, :request_link_supports_ajax_call, :source_data
# PrimoSources are not for everyone as they require programming but they do allow further customization 
# and functionality as necessary.
#
# == Further Documentation
# Exlibris::Primo::Holding provides further documentation related to creating local sources.
#
# ==Examples
# Two examples of customized sources are:
# * Exlibris::Primo::Source::Aleph 
# * Exlibris::Primo::Source::Local::NYUAleph 
class PrimoSource < PrimoService

  # Overwrites PrimoService#new.
  def initialize(config)
    @service_types = ["holding"]
    super(config)
  end

  # Overwrites PrimoService#handle.
  def handle(request)
    primo_sources = request.get_service_type('primo_source', {})
    sources_seen = Array.new # for de-duplicating holdings from catalog.
    primo_sources.each do |primo_source|
      source = primo_source.view_data
      # There are some cases where source records may need to be de-duplicated against existing records
      # Check if we've already seen this record.
      seen_sources_key = source.source_id.to_s + source.source_record_id.to_s
      next if source.dedup? and sources_seen.include?(seen_sources_key)
      # If we get this far, record that we've seen this holding.
      sources_seen.push(seen_sources_key)
      # There may be multiple holdings mapped to one availlibrary here, 
      # so we get the additional holdings and add them.
      source.expand.each do |holding|
        service_data = {}
        @holding_attributes.each do |attr|
          service_data[attr] = holding.method(attr).call
        end
        service_data.merge!({
          :call_number => holding.call_number, :collection => holding.collection,
          :collection_str => "#{holding.library} #{holding.collection}",
          :coverage_str => holding.coverage.join("<br />"),
          :coverage_str_array => holding.coverage,
  				# :expired determines whether we show the holding in this service
  				# Since this is fresh, the data has not yet expired.
  				:expired => false, 
   				# :latest determines whether we show the holding in other services, e.g. txt and email.
  				# It persists for one more cycle than :expired so services that run after
  				# this one, but in the same resolution request have access to the latest holding data.
          :latest => true
        })
        request.add_service_response(
          service_data.merge(
            :service=>self,
            :service_type_value => "holding" 
          )
        )
      end
    end
    return request.dispatched(self, true)
  end
end
