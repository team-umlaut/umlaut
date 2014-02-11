require 'test_helper'

require 'referent'
require 'dissertation_catch'


class DissertationCatchTest <  ActiveSupport::TestCase
  # this was a regression
  def test_blank_atitle
    context_object = OpenURL::ContextObject.new_from_kev("atitle=&title=Between+Us+and+Artistic+Appreciation%3a+Nabokov+and+the+Problem+of+Distortion&issn=04194209")

    # Not sure how we get a blank atitle in there, but we want DissertationCatch to handle it
    referent       = Referent.new
    referent.set_values_from_context_object(context_object)
    referent.ensure_value!("atitle", "")
    referent.referent_values(true) # reload

    DissertationCatch.new.filter(referent)

    assert_equal "Between Us and Artistic Appreciation: Nabokov and the Problem of Distortion", referent.metadata['title']    
  end
end