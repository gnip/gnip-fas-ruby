#A command-line wrapper to the fa_search class.
#Uses the 'optparse' gem for parsing command-line options.  For better or worse...
#The code here focuses on parsing command-line options, config files, then calling get_data or get_counts methods.

#Loads up rules, and loops through them.
#Writes to standard-out, files or to a database.

#Example usage: see README.md

require_relative "./lib/fa_search.rb"

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

    require 'optparse'
    require 'base64'

    #-------------------------------------------------------------------------------------------------------------------
    #Example command-lines

    #Options:
    #       Pass in configuration and rules files.
    #       Pass in everything on command-line.
    #       Pass in configuration file and all search parameters.
    #       Pass in configuration parameters and rules file.

    #Pass in two files, the Gnip Search API config file and a Rules file.
    # $ruby ./search_api.rb -c "./SearchConfig.yaml" -r "./rules/mySearchRules.yaml"
    # $ruby ./search_api.rb -c "./SearchConfig.yaml" -r "./rules/mySearchRules.json"

    #Typical command-line usage.
    # Specifying URL.  Passing in ISO formatted dates.
    # $ruby ./search_api.rb -a "http://search.gnip.com/" -u UserName@here.com -pMyPassword -r "rain OR weather (profile_region:colorado)" -s "2013-10-18 06:00" -e "2013-10-20 06:00"

    #Get minute counts.  Returns JSON time-series of minute, hour, or day counts.
    # $ruby ./search_api.rb -l -d "minutes"
    #               -a "http://search.gnip.com/" -u UserName@here.com -pMyPassword
    #               -r "rain OR weather (profile_region:colorado)" -s "2013-10-18 06:00" -e "2013-10-20 06:00"

    # Passing in configuration file to specify Search API URL, dates as YYYYMMDDHHMM. Passing in search parameters.
    #$ruby ./search_api.rb -c "./SearchConfig.yaml"
    #                -r "rain OR weather (profile_region:colorado)" -s "201310180600" -e "201310200600"

    # $ruby ./search_api.rb [-r RULE] [-s SEARCH_URL] [-u USERNAME] [-p PASSWORD] [-c COUNT_ONLY]
    #-------------------------------------------------------------------------------------------------------------------

    OptionParser.new do |o|

        #We need either a config file AND a rule parameter (which can be a single rule passed in, or a rules file)
        # OR
        #100% parameters, with no config file:
        # Mandatory: username, password, address/account, rule
        # Options: start(defaults to Now - 30 days), end (defaults to Now), tag,
        # look, duration (defaults to minute), maxResults (defaults to 100)

        #Passing in a config file.... Or you can set a bunch of parameters.
        o.on('-c CONFIG', '--config', 'Configuration file (including path) that provides account and download settings.
                                       Config files include username, password, account name and stream label/name.') { |config| $config = config}
        #Search rule.  This can be a single rule ""this exact phrase\" OR keyword"
        o.on('-r RULE', '--rule', 'Rule details.  Either a single rule passed in, or a file containing either a
                                   YAML or JSON array of rules.') {|rule| $rule = rule}

        #Basic Authentication.
        o.on('-u USERNAME','--user', 'User name for Basic Authentication.  Same credentials used for console.gnip.com.') {|username| $username = username}
        o.on('-p PASSWORD','--password', 'Password for Basic Authentication.  Same credentials used for console.gnip.com.') {|password| $password = password}
        #Search URL, based on account name.
        o.on('-a ADDRESS', '--address', 'Either Search API URL, or the account name which is used to derive URL.') {|address| $address = address}
        o.on('-n NAME', '--name', 'Label/name used for Stream API. Required if account name is supplied on command-line,
                                   which together are used to derive URL.') {|name| $name = name}

        #Period of search.  Defaults to end = Now(), start = Now() - 30.days.
        o.on('-s START', '--start_date', "UTC timestamp for beginning of Search period.
                                         Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.") { |start_date| $start_date = start_date}
        o.on('-e END', '--end_date', "UTC timestamp for ending of Search period.
                                      Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.") { |end_date| $end_date = end_date}

        #Search rule.  This can be a single rule "\"this exact phrase\" OR keyword"
        o.on('-r RULE', '--rule', 'A single rule passed in on command-line, or a file containing multiple rules.') {|rule| $rule = rule}
        #Tag, optional.  Not in payload, but triggers a "matching_rules" section with rule/tag values.
        o.on('-t TAG', '--tag', 'Optional. Gets included in the  payload if included. Alternatively, rules files can contain tags.') {|tag| $tag = tag}

        o.on('-o OUTBOX', '--outbox', 'Optional. Triggers the generation of files and where to write them.') {|outbox| $outbox = outbox}
        o.on('-z', '--zip', 'Optional. If writing files, compress the files with gzip.') {|zip| $zip = zip}

        #These trigger the estimation process, based on "duration" bucket size.
        o.on('-l', '--look', '"Look before you leap..."  Trigger the return of counts only.') {|look| $look = look}  #... as in look before you leap.
        o.on('-d DURATION', '--duration', "The 'bucket size' for counts, minute, hour (default), or day" ) {|duration| $duration = duration}  #... as in look before you leap.

        o.on('-m MAXRESULTS', '--max', 'Specify the maximum amount of data results.  10 to 500, defaults to 100.') {|max_results| $max_results = max_results}  #... as in look before you leap.

        #Help screen.
        o.on( '-h', '--help', 'Display this screen.' ) do
            puts o
            exit
        end

        o.parse!
    end

    #Create a Rehyrdation PowerTrack object, passing in an account configuration file.
    oSearch = FaSearch.new()
    oSearch.rules.rules = Array.new

    #Provided config file, which can include many things, especially username, password, account and stream names.
    if !$config.nil?
        oSearch.get_system_config($config)
    end

    #So, we got what we got from the config file, so process what was passed in.
    #Initial "gate-keeping" on what we have been provided.  Enough information to proceed?
    #Anything on command-line overrides configuration setting...

    error_msgs = Array.new

    #We need to have authentication details, username and password =====================================================
    if !$username.nil?
        oSearch.user_name = $username
    end

    if oSearch.user_name.nil? or oSearch.user_name == ""
        error_msgs << "User name is required. You can pass this in on command-line or specify in configuration file."
    end

    if !$password.nil?

        if oSearch.password_encoded?($password)
            oSearch.password_encoded = $password
        else
           oSearch.password = $password
           oSearch.password_encoded = Base64.encode64(oSearch.password)
        end
    end

    if (oSearch.password.nil? or oSearch.password == "") and (oSearch.password_encoded == "") then
        error_msgs << "Password is required. You can pass this in on command-line or specify in configuration file."
    end

    #We need to have account name and stream label (name), unless the Search API URL is provided =======================

    if !$address.nil?
        #Do we have a URL or an account name?
        if !$address.include?("data-api")  #we have an account name
            oSearch.account_name = $address
        else #we have a Search URL with form: https://search.gnip.com/accounts/jim/search/prod.json
            #Parse out account name and stream name/label.
            parts = $address.split("/")
            oSearch.account_name = parts[-3]
            oSearch.label = parts[-1].split(".")[-2]
        end
    end

    #See if we have a stream label/name being provided.
    if !$name.nil?
        oSearch.label = $name
    end

    #OK, now we should have both account_name and label, otherwise add another error message.
    if oSearch.account_name.nil? or oSearch.account_name == ""
        error_msgs << "Account name is required. You can pass this in on command-line or specify in configuration file."
    end

    if oSearch.label.nil? or oSearch.label == ""
        error_msgs << "Search label is required. You can pass this in on command-line or specify in configuration file."
    end

    oSearch.set_http

    #We need to have at least one rule.
    if !$rule.nil?
        #Rules file provided?
        extension = $rule.split(".")[-1]
        if extension == "yaml" or extension == "json"
            oSearch.rules_file = $rule
            if extension == "yaml" then
                oSearch.rules.loadRulesYAML(oSearch.rules_file)
            end
            if extension == "json"
                oSearch.rules.loadRulesYAML(oSearch.rules_file)
            end


        else
            rule = {}
            rule["value"] = $rule
            oSearch.rules.rules << rule
        end
    else
        error_msgs << "Either a single rule or a rules files is required. "
    end

    #Everything else is option or can be driven by defaults.

    #Tag is completely optional.
    if !$tag.nil?
        rule = {}
        rule = oSearch.rules.rules
        rule[0]["tag"] = $tag
    end

    #Look is optional.
    #Duration is optional, defaults to "hour" which is handled by Search API.
    #Can only be "minute", "hour" or "day".
    if !$duration.nil?
        if !['minute','hour','day'].include?($duration)
            p "Warning: unrecognized duration setting, defaulting to 'minute'."
            $duration = 'minute'
        end
    end

    #start_date, defaults to NOW - 30.days by Search API.
    #end_date, defaults to NOW by Search API.
    # OK, accepted parameters gets a bit fancy here.
    #    These can be specified on command-line in several formats:
    #           YYYYMMDDHHmm or ISO YYYY-MM-DD HH:MM.
    #           14d = 14 days, 48h = 48 hours, 360m = 6 hours
    #    Or they can be in the rules file (but overridden on the command-line).
    #    start_date < end_date, and end_date <= NOW.

    #We need to end up with PowerTrack timestamps in YYYYMMDDHHmm format.
    #If numeric and length = 12 then we are all set.
    #If ISO format and length 16 then apply o.gsub!(/\W+/, '')
    #If ends in m, h, or d, then do some time.add math

    #Handle start date.
    #First see if it was passed in
    if !$start_date.nil?
        oSearch.from_date = oSearch.set_date_string($start_date)
    end

    #Handle end date.
    #First see if it was passed in
    if !$end_date.nil?
        oSearch.to_date = oSearch.set_date_string($end_date)
    end

    #Max results is optional, defaults to 100 by Search API.
    if !$max_results.nil?
        oSearch.max_results = $max_results
    end

    #Writing data to files.
    if !$outbox.nil?
        oSearch.out_box = $outbox
        oSearch.storage = "files"

        if !$zip.nil?
            oSearch.compress_files = true
        end
    end

    #Check for configuration errors.
    if error_msgs.length > 0
        puts "Errors in configuration: "
        error_msgs.each { |e|
          puts e
        }

        puts ""
        puts "Please check configuration and try again... Exiting."

        exit
    end

    #Wow, we made it all the way through that!  Documentation must be awesome...

    if $look == true #Handle count requests.
        oSearch.rules.rules.each do |rule|
            #puts "Getting counts for rule: #{rule["value"]}"
            results = oSearch.get_counts(rule["value"], oSearch.from_date, oSearch.to_date, $duration)
        end
    else #Asking for data!
        interval = "minute"
        oSearch.rules.rules.each do |rule|
            puts "Getting activities for rule: #{rule["value"]}"
            oSearch.get_data(rule["value"], oSearch.from_date, oSearch.to_date)
        end
    end
    #puts "Exiting"
end
