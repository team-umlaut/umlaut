require 'test_helper'

class ServiceResponseTest < ActiveSupport::TestCase
  setup do
    @service = ServiceStore.instantiate_service!("DummyService", nil)
  end


  def test_fulltext_highlighted
    request = fake_umlaut_request("resolve?isbn=1")
    request.add_service_response(
      :service => @service,
      :service_type_value => "fulltext",
      :display_text => "foo"
    )
    request.add_service_response(
      :service => @service,
      :service_type_value => "holding",
      :display_text => "foo"
    )
    request.add_service_response(
      :service => @service,
      :service_type_value => "document_delivery",
      :display_text => "foo"
    )

    highlights = Umlaut::SectionHighlights.new(request)

    assert_equal ["fulltext"], highlights.highlighted_sections
  end

  def test_docdel_highlighted
    request = fake_umlaut_request("resolve?genre=book&isbn=1")
    request.add_service_response(
      :service => @service,
      :service_type_value => "document_delivery",
      :display_text => "foo"
    )

    highlights = Umlaut::SectionHighlights.new(request)

    assert_equal ["document_delivery"], highlights.highlighted_sections
  end

  def test_nothing_highlighted
    request = fake_umlaut_request("resolve?genre=book&isbn=1")

    highlights = Umlaut::SectionHighlights.new(request)

    assert_equal [], highlights.highlighted_sections
  end

  def test_holding_highlighted_for_book
    request = fake_umlaut_request("resolve?genre=book&isbn=1")
    request.add_service_response(
      :service => @service,
      :service_type_value => "holding",
      :display_text => "foo"
    )
    request.add_service_response(
      :service => @service,
      :service_type_value => "document_delivery",
      :display_text => "foo"
    )

    highlights = Umlaut::SectionHighlights.new(request)

    assert_equal ["holding"], highlights.highlighted_sections
  end

  def test_holding_and_docdel_for_article
    request = fake_umlaut_request("resolve?genre=article&doi=1")
    request.add_service_response(
      :service => @service,
      :service_type_value => "holding",
      :display_text => "foo"
    )
    request.add_service_response(
      :service => @service,
      :service_type_value => "document_delivery",
      :display_text => "foo"
    )

    highlights = Umlaut::SectionHighlights.new(request)

    assert_equal ["holding", "document_delivery"].sort, highlights.highlighted_sections.sort
  end

  def test_section_highlights_filter
    request = fake_umlaut_request("resolve?isbn=1")
    request.add_service_response(
      :service => @service,
      :service_type_value => "fulltext",
      :display_text => "foo"
    )

    config = Confstruct::Configuration.new
    # Filters has to mutate 'sections' if it wants to change it
    config.add_section_highlights_filter! Proc.new {|request, sections, highlights|
      sections.clear
    }

    highlights = Umlaut::SectionHighlights.new(request, config)

    assert_equal [], highlights.highlighted_sections
  end






end