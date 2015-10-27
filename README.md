# gnip-fas-ruby
Example Ruby app for Full-Archive Search


***
***Ruby Client for Gnip Historical Full-archive Search API***
***

***Gnip Full-archive Search API***

Search requests to the Full-Archive Search API allow you to query the complete historical archive of publicly avaialble Tweets. It can be used to retrieve all results associated with a query (with pagination if needed), or perhaps the most recent results for a high-volume query. Central to the Full-Archive Search API is the ability to ask about the *number* of Tweets associated with a query.

More information on the Full-Archive Search API can be found [HERE](http://support.gnip.com/apis/search_full_archive_api/).

***So, what does this Gnip Full-Archvie Search API client do?***

This Ruby client is a wrapper around the Full-Archive Search API. It was written to be a flexible tool for managing Full-Archive Search API requests. Here are some of the features:

* Rules can be submitted in a variety of ways: multiple rules from a JSON or YAML file or a single rule passed in via the command-line.  
* Results for the entire request period will be returned.  The script manages a pagination process that makes multiple requests if necessary.  
* Data can be provided in three ways: exported as files, written to a database, or written to standard out.
* Activity counts can be returned by using the "-l" parameter (as in 'look before you leap').  Counts by minute, by hour, or by day can be returned.
* Appends gnip:matching_rules metadata to the returned JSON payload.  If rules include tags, these metadata are appended as well.
* Search start and end time can be specified in several ways: standard PowerTrack timestamps (YYYYMMDDHHMM), 
  ISO 8061/Twitter timestamps (2013-11-15T17:16:42.000Z), as "YYYY-MM-DD HH:MM", and also with simple notation indicating the number of minutes (30m), hours (12h) and days (14d).
* Configuration and rule details can be specified by passing in files or specifying on the command-line, or a combination of both.  Here are some quick example:
  * Using configuration and rules files, requesting 30 days: $ruby fa_search_api.rb -c "./myConfig.yaml" -r "./myRules.json"
  * Using configuration and rules in files, requesting last 7 days: $ruby fa_search_api.rb -c "./myConfig.yaml" -r "./myRules.json" -s 7d
  * Specifying everything on the command-line: $ruby fa_search_api.rb -u me@there.com -p password -a http://search.gnip.com/accounts/jim/search/prod.json -r "snow deep" -s 7d 

