(function($) {
    
    function Loader() {
      this.load = function(option_list) {
         throw('Umlaut Loader object no longer supported.');
      }
    }    
    //Export it to the global object. 
    if (window.Umlaut == undefined)
      window.Umlaut = new Object();
    window.Umlaut.Loader = Loader;
    
})(jQuery);
