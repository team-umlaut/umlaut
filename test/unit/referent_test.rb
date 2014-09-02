require 'test_helper'


class ReferentTest < ActiveSupport::TestCase

  def test_ensure_value
    referent = Referent.new
    referent.save!

    referent.ensure_value!("title", "this is a title")  
    assert_present (referent.referent_values(true).to_a.find {|rv| rv.key_name = "title" && rv.value == "this is a title"}), "referent value not saved"
  end

  def test_enhance_referent
    referent = Referent.new
    referent.save!
    referent.ensure_value!("title", "this is a title")  

    another_reference = Referent.find(referent.id)
    refute_same referent, another_reference
    another_reference.enhance_referent("title", "new title")

    # Make sure there's only one referent_value with key 'title', and it has
    # our new value
    rvs = another_reference.referent_values(true)

    assert_length 1, rvs

    assert_equal "title", rvs.first.key_name
    assert_equal "new title", rvs.first.value
  end


end
