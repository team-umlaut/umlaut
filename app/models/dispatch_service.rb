# jrochkind believes this is legacy unused code. 
# all the dispatch services in app/models/dispatch_services inherit from this
class DispatchService
	def cleanse_url(url)
		if url.match(/^http:\/\/www\.library\.gatech\.edu:2048\/login/)
			url.sub!(/^http:\/\/www\.library\.gatech\.edu:2048\/login\?.?url=/, '')
		end

		if url.match(/dx\.doi\.org/)
			url.sub!(/\?nosfx=y/,'')
		end
		return url
	end
end
