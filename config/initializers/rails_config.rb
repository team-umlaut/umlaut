# To keep db password from showing up in log, we need to trick the logger. Weird, sorry.
  orig_logger = ActiveRecord::Base.logger 
  ActiveRecord::Base.logger = nil

  ActiveRecord::Base.allow_concurrency = true

  ActiveRecord::Base.logger = orig_logger

