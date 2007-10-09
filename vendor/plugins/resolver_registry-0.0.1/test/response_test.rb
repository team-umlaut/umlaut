class ResponseTest < Test::Unit::TestCase

  def setup
    xml = File.read('test/sample.xml')
    @response = ResolverRegistry::Response.new(xml)
  end

  def test_institution
    institution = @response.institutions[0]
    assert_kind_of ResolverRegistry::Institution, institution
    assert_equal "GEORGIA INST OF TECH", institution.name
    assert_equal 9, institution.ip_ranges.length
    assert_equal "130.207.0.0", institution.ip_ranges[0]
    assert_equal "128.61.*.*", institution.ip_ranges[8]
    # TODO: check other attributes here
  end

  def test_resolvers
    institution = @response.institutions[0]
    assert_kind_of ResolverRegistry::Resolver, institution.resolver
    assert_kind_of Array, institution.resolvers
    assert_equal 1, institution.resolvers.length
  end

  def test_resolver
    resolver = @response.institution.resolver
    assert_equal 'FirstSearch', resolver.source
    assert_equal 'http://findit.library.gatech.edu/resolve', resolver.base_url
    # TODO: check other attributes here
  end
end
