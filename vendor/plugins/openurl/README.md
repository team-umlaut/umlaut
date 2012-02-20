# openurl

## DESCRIPTION

openurl is a Ruby library creating, parsing and using NISO Z39.88 OpenURLs over 
HTTP. <http://openurl.info/registry>

While openurl can send requests to OpenURL 1.0 resolvers, there is no 'standard'
response format, so parsing the returned value is up to you.

## USAGE
  
    require 'openurl'    
  
    # Create your context object
    context_object = OpenURL::ContextObject.new
  
    # Add metadata to the Context Object Entities
    context_object.referent.set_format('journal')
    context_object.referent.add_identifier('info:doi/10.1016/j.ipm.2005.03.024')
    context_object.referent.set_metadata('issn', '0306-4573')
    context_object.referent.set_metadata('aulast', 'Bollen')
    context_object.referrer.add_identifier('info:sid/google')
    
    puts context_object.kev  
  
    puts context_object.xml  
    
    # Send the context object to an OpenURL link resolver
    transport = OpenURL::Transport.new('http://demo.exlibrisgroup.com:9003/lr_3', context_object)
    transport.get
    puts tranport.response
    
    # Create a new ContextObject from an existing kev or XML serialization:
    #
    # ContextObject.new_from_kev(   kev_context_object )
    # ContextObject.new_from_xml(   xml_context_object ) # Can be String or REXML::Document

## Ruby 1.9 and encodings

Gem does run and all tests pass under ruby 1.9.  There is very limited
support for handling character encodings in the proper 1.9 way. 

CTX or XML context objects will be assumed utf-8 even if the ruby string
they are held in has an ascii-8bit encoding. They will forced into a utf-8 encoding. 
This seems to be a side effect of the REXML and CGI libraries we use to parse,
but there are runnable tests that assert it is true. (see test/encoding_test.rb)

Incoming context objects with a non-utf8 ctx_enc value will *not* be handled
properly, they'll still be forced to utf8. 

Programmatically created context objects, you must ensure all strings are
represented as utf8 encoded yourself.  

More sophisticated encoding handling can theoretically be added, but it's
somewhat non-trivial, and it's not clear anyone needs it. 

## INSTALLATION

You should be able to install the gem:

    gem install openurl

The source lives in git on github:

    http://github.com/openurl/openurl

## TESTS

There are some automated tests. Run with `rake test`. They live in `./test`
and use Test::Unit.
