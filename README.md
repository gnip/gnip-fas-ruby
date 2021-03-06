# gnip-fas-ruby
Example Ruby app for Full-Archive Search

***Ruby Client for Gnip Full-Archive Search API***

Search requests to the Full-Archive Search API allow you to query the complete historical archive of publicly available Tweets. It can be used to retrieve all results associated with a query (with pagination if needed), or perhaps the most recent results for a high-volume query. Central to the Full-Archive Search API is the ability to ask about the *number* of Tweets associated with a query.

More information on the Full-Archive Search API can be found [HERE](http://support.gnip.com/apis/search_full_archive_api/).

***So, what does this Gnip Full-Archive Search API client do?***

This Ruby client is a wrapper around the Full-Archive Search API. It was written to be a flexible tool for managing Full-Archive Search API requests. Here are some of the features:

* Rules can be submitted in a variety of ways: multiple rules from a JSON or YAML file or a single rule passed in via the command-line.  
* Results for the entire request period will be returned.  The script manages a pagination process that makes multiple requests if necessary.  
* Data can be provided in three ways: exported as files, written to a database, or written to standard out.
* Activity counts can be returned by using the "-l" parameter (as in 'look before you leap').  Counts by minute, by hour, or by day can be returned.
* Search start and end time can be specified in several ways: standard PowerTrack timestamps (YYYYMMDDHHMM), 
  ISO 8061/Twitter timestamps (2013-11-15T17:16:42.000Z), as "YYYY-MM-DD HH:MM", and also with simple notation indicating the number of minutes (30m), hours (12h) and days (14d).
* Configuration and rule details can be specified by passing in files or specifying on the command-line, or a combination of both.  Here are some quick examples:
  * Using configuration and rules files, requesting 30 days: $ruby fa_search_api.rb -c "./myConfig.yaml" -r "./myRules.json"
  * Using configuration and rules files, requesting last 7 days: $ruby fa_search_api.rb -c "./myConfig.yaml" -r "./myRules.json" -s 7d
  * Specifying everything on the command-line: $ruby fa_search_api.rb -u me@there.com -p password -a http://data-api.twitter.com/search/fullarchive/accounts/my_account/prod.json -r "snow deep" -s 7d
  
**Client Overview**

This client application helps manage the counts and data retrieval from the Gnip Full-Archive Search API. This search client supports submitting multiple rules.  A single rule can be passed in on the command-line, or a Rules file can be passed in and the client will make a set of Full-Archive Search API requests for each rule. 

Rules can be passed to the client in several ways:
 + One or more rules encoded in a JSON file and passed in via the command-line.
 + One or more rules encoded in a YAML file and passed in via the command-line.
 + Single rule passed in via the command-line.

There is an option to have a gnip:matching_rules section added to the returned JSON payload.  In addition, Rule Tags can be specified and included in the matching_rules section. 

The client can also use the "counts" mechanism to return only the activity counts based on days, hours or minutes.  If counts are requested ("-l" command-line option, as in "look before you leap"), an array of counts are returned.

**Specifying Search Start and End Times**

If no "start" and "end" parameters are specified, the Full-Archive Search API defaults to the most recent 30 days. "Start" time defaults to 30 days ago from now, and "End" time default to "now". Start (-s) and end (-e) parameters can be specified in a variety of ways:

* Standard PowerTrack format, YYYYMMDDHHmm (UTC)
   * -s 201511070700 -e 201511080700 --> Search 2013-11-07 MST. 
   * -s 201511090000 --> Search since 2015-11-09 00:00 UTC.
* A combination of an integer and a character indicating "days" (#d), "hours" (#h) or "minutes" (#m).  Some examples:
   * -s 1d --> Start one day ago (i.e., search the last day)
   * -s 14d -e 7d --> Start 14 days ago and end 7 days ago (i.e. search the week before last)  
   * -s 6h --> Start six hours ago (i.e. search the last six hours) 
* "YYYY-MM-DD HH:mm" (UTC, use double-quotes please)
   * -s "2015-11-04 07:00" -e "2015-11-07 06:00" --> Search 2015-11-04 and 2015-11-05 MST.
* "YYYY-MM-DDTHH:MM:SS.000Z" (ISO 8061 timestamps as used by Twitter, in UTC)
   * -s 2015-11-20T15:39:31.000Z --> Search beginning at 2015-11-20 22:39 MST (note that seconds are dropped).

**Command-line options**

At a minimum, the following parameters are needed to make a Full-Archive Search API request:

* Authentication details: username and password.  They can be provided on command-line or as part of a specified configuration file.
* Account and stream names or Full-Archive Search API URL.  If account and stream names are provided, the Full-Archive Search URLs are generated from that information. 
* At least one rule/filter. A single rule can be passed in on the command-line, or one or more passed in from a rules file.
* There are three output options: activities can simply returned from script as "standard out", written to data files, or written to a database.  If no configuration file is used, data will be written to standard out.  Otherwise you can specify your output preference in the config file. If writing to data files or a database you must specify the details in the config file (e.g. output folder, database connection details).


```
Usage: search_api [options]
    -c, --config CONFIG              Configuration file (including path) that provides account and download settings.
                                         Config files include username, password, account name and stream label/name.
    -u, --user USERNAME              User name for Basic Authentication.  Same credentials used for console.gnip.com.
    -p, --password PASSWORD          Password for Basic Authentication.  Same credentials used for console.gnip.com.
    -a, --address ADDRESS            Either Search API URL, or the account name which is used to derive URL.
    -n, --name NAME                  Label/name used for Stream API. Required if account name is supplied on command-line,
                                         which together are used to derive URL.
    -s, --start_date START           UTC timestamp for beginning of Search period.
                                         Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM" or use ##d, ##h or ##m.
    -e, --end_date END               UTC timestamp for ending of Search period.
                                        Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -r, --rule RULE                  A single rule passed in on command-line, or a file containing multiple rules.
    -t, --tag TAG                    Optional. Gets tacked onto payload if included. Alternatively, rules files can contain tags.
    -o, --outbox OUTBOX              Optional. Triggers the generation of files and where to write them.
    -z, --zip                        Optional. If writing files, compress the files with gzip.
    -l, --look                       "Look before you leap..."  Trigger the return of counts only.
    -d, --duration DURATION          The 'bucket size' for counts, 'minute', 'hour' (default), or 'day'.
    -m, --max MAXRESULTS             Specify the maximum amount of data results.  10 to 500, defaults to 100.
    -h, --help                       Display this screen.

```

**Configuration Files**

Many app and Full-Archive Search API options can be specified in a configuration (YAML) file as an alternative to passing in settings via the command-line.  Please note that if you are writing data to a database you must specify the database details in a configuration file.

```yaml
#Account details.
account:
  account_name: my_account_name  #Used in URL for Gnip APIs.
  user_name: me@mycompany.com
  password_encoded: PaSsWoRd_EnCoDeD  #At least some resemblance of security. Generated by "base64" Ruby Gem.
  #password: PlainTextPassword  #Use this is you want to use plain text, and comment out the encoded entry above.

#Search API configuration details:

search:
  label: prod
  write_rules: true
  compress_files: true
  storage: files #options: files, database, standard_out --> Store activities in local files, in database. or print to system out?
  out_box: ./search_out #Folder where retrieved data goes.
  
#Note that if you want to write to a database, the connection details must be specified in this file.
database:
  host: 127.0.0.1
  port: 3306
  #Note: currently all PowerTrack example clients share a common database schema.
  schema: power-track_development
  user_name: root
  password_encoded:
  #password: test
  type: mysql

```


**Rules Files**

Multiple rules can be specified in JSON or YAML files.  Below is an example of each. Note that an individual rule can be specified on the command-line. 

JSON rules file:

```json
{
  "rules" :
    [
        {
          "value" : "snow colorado",
          "tag" : "ski_biz"
        },
        {
          "value" : "snow utah",
          "tag" : "ski_biz"
        },
        {
          "value" : "rain washington",
          "tag" : "umbrellas"
        }
    ]
}
```
YAML rules file:
```yaml
rules:
  - value  : "snow colorado"
    tag    : ski_biz
  - value  : "snow utah"
    tag    : ski_biz
  - value  : "rain washington"
    tag    : umbrellas
```

***Getting Started***

+ Get access to Full-Archive Search API from Gnip, establish username and password.
+ Clone respository.
+ bundle install. See project Gem file. Need some basic gems like 'json', 'yaml', and 'zlib'. 
+ Configure the config.yaml. 
+ Test it out by running $ruby fa_search_app.rb  -c "./config/config.yaml" -r "gnip" -s 7d
+ Look for API JSON responses in app's standard out, outbox, or in the configured database. 

 
  


