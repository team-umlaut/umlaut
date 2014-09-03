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

    Rails.logger.info("----ENHANCE BEGIN----")

    another_reference.enhance_referent("title", "new title")

    Rails.logger.info("----ENHANCE END----")

    # Make sure there's only one referent_value with key 'title', and it has
    # our new value
    rvs = another_reference.referent_values(true)

    assert_length 1, rvs

    assert_equal "title", rvs.first.key_name
    assert_equal "new title", rvs.first.value
  end

  def test_create_by_context_object
    url = "?url_ver=Z39.88-2004&url_ctx_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Actx&ctx_ver=Z39.88-2004&ctx_tim=2014-09-03T09%3A56%3A22-04%3A00&ctx_id=&ctx_enc=info%3Aofi%2Fenc%3AUTF-8&rft.genre=article&rft.au=Chen%2C+Yu-Hui&rft.date=2009-05-01&rft.volume=60&rft.issue=5&rft.spage=953&rft.jtitle=Journal+of+the+American+Society+for+Information+Science+%26+Technology&rft.issn=15322882&rft.pub=Wiley-Blackwell&rft.atitle=An+exploration+into+the+practices+of+library+Web+usability+in+ARL+academic+libraries.&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Ajournal&rft_id=info%3Adoi%2F10.1002%2Fasi.21032&rfr_id=http%3A%2F%2Fcatalyst.library.jhu.edu%2Fsearch%2Farticles"
    co  = OpenURL::ContextObject.new_from_form_vars(Request.context_object_params(fake_rails_request( url )))
    
    rft = Referent.create_by_context_object(co)

    assert rft.persisted?

    rft_values = rft.referent_values
    assert rft_values.all? {|rv| rv.persisted?}

    [
      ["atitle", "An exploration into the practices of library Web usability in ARL academic libraries."],
      ['au', 'Chen, Yu-Hui'],
      ['date', '2009-05-01'],
      ['format', 'journal'],
      ['genre', 'article'],
      ['identifier', 'info:doi/10.1002/asi.21032'],
      ['issn', '15322882'],
      ['issue', '5'],
      ['jtitle', 'Journal of the American Society for Information Science & Technology'],
      ['pub', 'Wiley-Blackwell'],
      ['spage', '953'],
      ['volume', '60'],
    ].each do |key, value|
      assert (rft_values.find {|rv| rv.key_name == key && rv.value == value}), "Missing expected referent_value with key #{key}"
    end
  end


end
