class StoreController < ApplicationController
  require 'open_url'
  def index
    perm = Permalink.find(params[:id])
    co = OpenURL::ContextObject.new
    co.import_context_object(perm.referent.to_context_object)
    redirect_to(co.to_hash.merge({:controller=>"resolve", :action=>'index'}))
  end
end
