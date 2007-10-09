require 'resolver_registry'

class ClientTest < Test::Unit::TestCase

  def test_constructor
    client = ResolverRegistry::Client.new
    assert_kind_of ResolverRegistry::Client, client
  end

  def test_lookup
    client = ResolverRegistry::Client.new
    institution = client.lookup('130.207.50.91')
    assert_kind_of ResolverRegistry::Institution, institution
  end

  def test_lookup_all
    client = ResolverRegistry::Client.new
    institutions = client.lookup_all('130.207.50.91')
    assert_kind_of Array, institutions
    assert_equal 1, institutions.length
    assert_kind_of ResolverRegistry::Institution, institutions[0]
  end

end
