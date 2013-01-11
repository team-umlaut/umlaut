# == Overview
# PrimoSource is a PrimoService that converts primo_source service types into Primo source holdings.
# This mechanism allows linking to original data sources and their holdings information
# based on the given Primo sources and can be implemented per source.
# 
# PrimoSources are not necessary to use the Primo service andthey require programming.
# However, they do allow further customization and functionality.
# 
class PrimoSource < PrimoService

  # Overwrites PrimoService#new.
  def initialize(config)
    @service_types = ["holding"]
    @source_attributes = []
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
          service_data[attr] = holding.send(attr.to_sym) if holding.respond_to?(attr.to_sym)
        end
        @source_attributes.each do |attr|
          service_data[attr.to_sym] = holding.send(attr.to_sym) if holding.respond_to?(attr.to_sym)
        end
        service_data.merge!({
          :url => holding.url,
          :request_link_supports_ajax_call => ((holding.respond_to?(:request_link_supports_ajax_call)) ?
            holding.request_link_supports_ajax_call : false),
          :collection_str => "#{holding.library} #{holding.collection}",
          :coverage_str => holding.coverage.join("<br />"),
          :coverage_str_array => holding.coverage,
          # :expired determines whether we show the holding in this service
          # Since this is fresh, the data has not yet expired.
          :expired => false,
          # :latest determines whether we show the holding in other services, e.g. txt and email.
          # It persists for one more cycle than :expired so services that run after
          # this one, but in the same resolution request have access to the latest holding data.
          :latest => true })
        request.add_service_response(
          service_data.merge(:service=>self,
            :service_type_value => "holding" ))
      end
    end
    return request.dispatched(self, true)
  end
end