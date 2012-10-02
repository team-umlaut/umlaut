SearchMethods
===
SearchMethods' allow Umlaut to search an arbitrary data source for A-Z Journals.
Implementations must adhere to the following method signatures.
The module is included in the SearchController and has access to instance methods and
instance variables from the SearchController.

Class Methods:
--- 
  - ::fetch_urls?() ==> Boolean <br>
  Returns a Boolean indicating whether the module will return URLs
  
  - ::fetch_urls() ==> [Array<String>] <br>
  Returns an array of strings representing URLs that are "owned" by the search
  system

Instance Methods:
---
  - find_by_title() ==> [[Array<OpenURL::ContextObject>], integer] <br>
  Returns a two element array consisting of an Array of OpenURL::ContextObject
  and the total count of records returned by the search
  
  - find_by_group() ==> [[Array<OpenURL::ContextObject>], integer] <br>
  Returns a two element array consisting of an Array of OpenURL::ContextObject
  and the total count of records returned by the search
