# Kind of analagous to SFX "source parser". Takes ContextObjects
# passed in, and filters/mutates them.
#
# specific subclasses in lib/context_object_filters
#
# configured to apply in environment.rb

class ReferentFilter

  # input: Referent object
  # will mutate/modify it. 
  def filter(referent)
    # implement in subclass
  end
 
end
