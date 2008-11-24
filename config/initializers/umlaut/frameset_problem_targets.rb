  # SFX Targets and other urls that we know have a problem with
  # being put in a frameset, and exclude from direct linking
  # in frameset. Some escape the frameset with javascript,
  # others run into problems with cookies in a frameset
  # environment.
  
  AppConfig::Base.frameset_problem_targets = { :sfx_targets => [], :urls => [] }
  # Two lists, one that match SFX target names, another that match actual
  # destination urls. Either can be a string (for exact match) or a REGEXP. 
  AppConfig::Base.frameset_problem_targets[:sfx_targets] = [
       /^WILSON\_/,
        /^SAGE\_/,
      # HIGHWIRE_PRESS_FREE is a collection of different hosts,
      # but MANY of them seem to be frame-escapers, so we black list them all!
      # Seems to be true of HIGHWIRE_PRESS stuff in general in fact, they're
      # all blacklisted.
        /^HIGHWIRE_PRESS/,
        /^OXFORD_UNIVERSITY_PRESS/,
      # Springer (METAPRESS and SPRINGER_LINK) has a weird system requiring
      # cookies to get to a full text link. The cookies don't like the frameset
      #, so it ends up not working in frameset on some computers, somewhat hard 
      # to reproduce.
        /^METAPRESS/,
        /^SPRINGER_LINK/,
      # Cookie/frameset issue. Reproducible on IE7, not on Firefox. 
        /^WILEY_INTERSCIENCE/,
      # And now Wiley stuff is actually in Synergy
        /^SYNERGY_BLACKWELL/,
      # Mysterious problem in frameset but not direct link, in IE only.
      # Assume cookie problem. Could be wrong, very very low reproducibilty.
       'LAWRENCE_ERLBAUM_ASSOCIATES_LEA_ONLINE',
      # This one is mysterious too, seems to effect even non-frameset
      # linking sometimes? Don't understand it, but guessing cookie
      # frameset issue.
      'INFORMAWORLD_JOURNALS'
      ]

    # note that these will sometimes be proxied urls!
    # So we don't left-anchor the regexp. 
    AppConfig::Base.frameset_problem_targets[:urls] = [
       /http\:\/\/www.bmj.com/,
       /http\:\/\/bmj.bmjjournals.com/, 
       /http\:\/\/www.sciencemag.org/,
       /http\:\/\/([^.]+\.)\.ahajournals\.org/,
       /http\:\/\/www\.circresaha\.org/,
       /http\:\/\/www.businessweek\.com/,
       /endocrinology-journals\.org/,
       /imf\.org/,
       # Weird hard to reproduce cookie issue
       /www\.ipap\.jp/
      ]

