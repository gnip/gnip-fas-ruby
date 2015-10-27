class FaSearch

    require "json"
    require "yaml" #Used for configuration files.
    require "base64"
    require "fileutils"
    require "zlib"
    require "time"

    #PowerTrack classes
    require_relative "../common/restful"
    require_relative "../common/database"
    require_relative "../common/rules"

    API_ACTIVITY_LIMIT = 500 #Limit on the number of activity IDs per Rehydration API request, can be overridden.

    attr_accessor :http, #need a HTTP object to make requests of.
                  :urlSearch, :urlCount, #Search uses two different end-points...

                  :account_name, :user_name,
                  :password, :password_encoded, #System authentication.
                  :product, :label,

                  :rules, #rules object.
                  :rules_file, #YAML (or JSON?) file with rules.
                  :write_rules, #Append rules/tags to collected JSON, if it is normalized AS format.
                  :compress_files,

                  :interval,
                  :max_results,
                  :from_date, :to_date, #'Study' period.
                  :request_from_date, :request_to_date, #May be breaking up 'study' period into separate smaller periods.
                  :count_page_total, #total of individual bucket counts per page/response.
                  :count_total,

                  :storage,
                  :in_box, :out_box,

                  :request_timestamp

    def initialize()

        #Defaults.
        @interval = "day"
        @max_results = API_ACTIVITY_LIMIT
        @out_box = "./"
        @request_timestamp = Time.now - 1

        @rules = PtRules.new #Helper class for loading rules from configuration files.

        #Set up a HTTP object.
        @http = PtRESTful.new #HTTP helper class.
    end

    #Attempts to determine if password is base64 encoded or not.
    #Uses this recipe: http://stackoverflow.com/questions/8571501/how-to-check-whether-the-string-is-base64-encoded-or-not
    def password_encoded?(password)
        reg_ex_test = "^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{4}|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)$"

        if password =~ /#{reg_ex_test}/ then
            return true
        else
            return false
        end
    end

    def password_encoded
        Base64.encode64(@password) unless @password.nil?
    end

    #Load in the configuration file details, setting many object attributes.
    def get_system_config(config_file)

        config = YAML.load_file(config_file)

        #Config details.

        #Parsing account details if they are provided in file.
        if !config["account"].nil? then
            if !config["account"]["account_name"].nil? then
                @account_name = config["account"]["account_name"]
            end

            if !config["account"]["user_name"].nil? then
                @user_name = config["account"]["user_name"]
            end

            if !config["account"]["password"].nil? or !config["account"]["password_encoded"].nil? then
                @password_encoded = config["account"]["password_encoded"]

                if @password_encoded.nil? then #User is passing in plain-text password...
                    @password = config["account"]["password"]
                    @password_encoded = Base64.encode64(@password)
                end
            end
        end

        if !config["search"]["label"].nil? then #could be provided via command-line
            @label = config["search"]["label"]
        end

        #User-specified in and out boxes.
        #@in_box = checkDirectory(config["search"]["in_box"])
        #Managing request lists that have been processed.
        #@in_box_completed = checkDirectory(config["search"]["in_box_completed"])

        @storage = config["search"]["storage"]

        begin
            @out_box = checkDirectory(config["search"]["out_box"])
        rescue
            @out_box = "./"
        end

        begin
            @compress_files = config["search"]["compress_files"]
        rescue
            @compress_files = false
        end

        #@write_rules = config["search"]["write_rules"]

        if @storage == "database" then #Get database connection details.
            db_host = config["database"]["host"]
            db_port = config["database"]["port"]
            db_schema = config["database"]["schema"]
            db_user_name = config["database"]["user_name"]
            db_password = config["database"]["password"]

            @datastore = Database.new(db_host, db_port, db_schema, db_user_name, db_password)
            @datastore.connect
        end
    end

    def set_http
        @http.user_name = @user_name #Set the info needed for authentication.
        @http.password_encoded = @password_encoded #HTTP class can decrypt password.

        @urlSearch = @http.getFaSearchURL(@account_name, @label)
        @urlCount = @http.getFaSearchCountURL(@account_name, @label)

        #Default to the "search" url.
        @http.url = @urlSearch #Pass the URL to the HTTP object.
    end


    def get_search_rules
        if !@rules_file.nil then #TODO: Add JSON option.
            @rules.loadRulesYAML(@rules_file)
        end
    end

    #-----------------------------------------------------
    #TODO: port to a separate 'common' module.
    #Confirm a directory exists, creating it if necessary.
    def checkDirectory(directory)
        #Make sure directory exists, making it if needed.
        if not File.directory?(directory) then
            FileUtils.mkpath(directory) #logging and user notification.
        end
        directory
    end

    def get_date_string(time)
        return time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)
    end

    def get_date_object(time_string)
        time = Time.new
        time = Time.parse(time_string)
        return time
    end

    def numeric?(object)
        true if Float(object) rescue false
    end

    #Takes a variety of string inputs and returns a standard PowerTrack YYYYMMDDHHMM timestamp string.
    def set_date_string(input)

        now = Time.new
        date = Time.new

        #Handle minute notation.
        if input.downcase[-1] == "m" then
            date = now - (60 * input[0..-2].to_f)
            return get_date_string(date)
        end

        #Handle hour notation.
        if input.downcase[-1] == "h" then
            date = now - (60 * 60 * input[0..-2].to_f)
            return get_date_string(date)
        end

        #Handle day notation.
        if input.downcase[-1] == "d" then
            date = now - (24 * 60 * 60 * input[0..-2].to_f)
            return get_date_string(date)
        end

        #Handle PowerTrack format, YYYYMMDDHHMM
        if input.length == 12 and numeric?(input) then
            return input
        end

        #Handle "YYYY-MM-DD 00:00"
        if input.length == 16 then
            return input.gsub!(/\W+/, '')
        end

        #Handle ISO 8601 timestamps, as in Twitter payload "2013-11-15T17:16:42.000Z"
        if input.length > 16 then
            date = Time.parse(input)
            return get_date_string(date)
        end

        return 'Error, unrecognized timestamp.'

    end

    #-----------------------------------------------------


    # TODO: needs to check for existing file name, and serialize if needed.
    # Payloads are descending chronological, first timestamp is end_time, last is start_time.  Got it?
    def get_file_name(rule, results)

        #Get start_time of this response payload.
        time = Time.parse(results.first['postedTime'])
        end_time = time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)  + sprintf('%02i', time.sec)

        #Get end_time of this response payload.
        time = Time.parse(results.last['postedTime'])
        start_time = time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)  + sprintf('%02i', time.sec)

        rule_str = rule.gsub(/[^[:alnum:]]/, "")[0..9]
        filename = "#{rule_str}_#{start_time}_#{end_time}"
        return filename
    end

    # TODO: needs to check for existing file name, and serialize if needed.
    # Payloads are descending chronological, first timestamp is end_time, last is start_time.  Got it?
    def get_counts_file_name(rule, results)

        #Get start_time of this response payload.
        time = Time.parse(results.first['timePeriod'])
        end_time = time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)  + sprintf('%02i', time.sec)

        #Get end_time of this response payload.
        time = Time.parse(results.last['timePeriod'])
        start_time = time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)  + sprintf('%02i', time.sec)

        rule_str = rule.gsub(/[^[:alnum:]]/, "")[0..9]
        filename = "#{rule_str}_#{start_time}_#{end_time}"
        return filename
    end

    #Builds a hash and generates a JSON string.
    #Defaults:
    #@interval = "hour"   #Set in constructor.
    #@max_results = API_ACTIVITY_LIMIT   #Set in constructor.

    def build_request(rule, from_date=nil, to_date=nil)
        request = {:query => rule}

        if !from_date.nil?
            request[:fromDate] = from_date
        end

        if !to_date.nil?
            request[:toDate] = to_date
        end

        return request
    end

    def build_counts_request(rule, from_date=nil, to_date=nil, interval=nil, next_token=nil)

        request = build_request(rule, from_date, to_date)

        if !interval.nil?
            request[:bucket] = interval
        else
            request[:bucket] = @interval
        end

        if !next_token.nil?
          request[:next] = next_token
        end

        return JSON.generate(request)
    end

    def build_data_request(rule, from_date=nil, to_date=nil, max_results=nil, next_token=nil)

        request = build_request(rule, from_date, to_date)

        if !max_results.nil?
            request[:maxResults] = max_results
        else
            request[:maxResults] = @max_results #This client
        end

        if !next_token.nil?
            request[:next] = next_token
        end

        return JSON.generate(request)
    end

    def get_count_total(count_response)

      count_total = 0
      
      #puts count_response

      contents = JSON.parse(count_response)
      results = contents["results"]
      results.each do |result|
        count_total = count_total + result["count"]
      end

      @count_page_total = count_total
    end
    
    def make_counts_request(rule, start_time, end_time, interval, next_token)

      @http.url = @urlCount

      results = {}
      @count_page_total = 0
     
      data = build_counts_request(rule, start_time, end_time, interval, next_token)

      if (Time.now - @request_timestamp) < 1 then
        sleep 1
      end
      @request_timestamp = Time.now
      
      begin
        response = @http.POST(data)
      rescue
        sleep 5
        response = @http.POST(data) #try again
      end

      #Parse response.body and build ordered array.
      temp = JSON.parse(response.body)

      next_token = temp['next']
      @count_page_total = temp['totalCount']
      @count_total = @count_total + @count_page_total

      results['total'] = @count_page_total

      results['results'] = temp['results']


      if @storage == "files" then #write the file.

          #Each 'page' has a start and end time, go get those for generating filename.

          filename = ""
          filename = get_counts_file_name(rule, temp['results'])

          p "Storing Search API data in file: #{filename}"

          if @compress_files then
              File.open("#{@out_box}/#{filename}.json.gz", 'w') do |f|
                  gz = Zlib::GzipWriter.new(f, level=nil, strategy=nil)
                  gz.write api_response.to_json
                  gz.close
              end
          else
              File.open("#{@out_box}/#{filename}.json", "w") do |new_file|
                  new_file.write(temp.to_json)
              end
          end
        else
            puts results
        end

      return next_token

    end

    def make_data_request(rule, start_time, end_time, max_results, next_token, tag)

        @http.url = @urlSearch
        data = build_data_request(rule, start_time, end_time, max_results, next_token)

        if (Time.now - @request_timestamp) < 1 then
            sleep 1
        end
        @request_timestamp = Time.now
        
        #puts data

        begin
            response = @http.POST(data)
        rescue
            sleep 5
            response = @http.POST(data) #try again
        end

        #Prepare to convert Search API JSON to hash.
        api_response = []
        api_response = JSON.parse(response.body)

        if !(api_response["error"] == nil) then
            puts "Handle error!"
        end

        if (api_response['results'].length == 0) then
           puts "No results returned."
           return api_response['next']
        end

        if @storage == "files" then #write the file.

            #Each 'page' has a start and end time, go get those for generating filename.

            filename = ""
            filename = get_file_name(rule, api_response['results'])

            p "Storing Search API data in file: #{filename}"

            if @compress_files then
                File.open("#{@out_box}/#{filename}.json.gz", 'w') do |f|
                    gz = Zlib::GzipWriter.new(f, level=nil, strategy=nil)
                    gz.write api_response.to_json
                    gz.close
                end
            else
                File.open("#{@out_box}/#{filename}.json", "w") do |new_file|
                    new_file.write(api_response.to_json)
                end
            end
        elsif @storage == "database" #store in database.
            puts "Storing Search API data in database..."

            results = []
            results = api_response['results']

            results.each do |activity|

                #p activity
                @datastore.storeActivity(activity.to_json)
            end
        else #Standard out
            results = []
            results = api_response['results']
            results.each do |activity|
                puts activity.to_json #Standard out...
            end
        end

        #Return next_token, or 'nil' if there is not one provided.
        return api_response['next']
    end


    def get_counts(rule, start_time, end_time, interval)

      next_token = 'first request'
      @count_total = 0

      time_span = "#{start_time} to #{end_time}.  "
      if start_time.nil? and end_time.nil? then
        time_span = "last 30 days."
      elsif start_time.nil? then
        time_span = "30 days ago to #{end_time}. "
      elsif end_time.nil?
        time_span = "#{start_time} to now.  "
      end

      puts "Retrieving counts from #{time_span}..."

      while !next_token.nil? do
        if next_token == 'first request' then
          next_token = nil
        end
        next_token = make_counts_request(rule, start_time, end_time, interval, next_token)
      end
      
      puts "Total counts: #{@count_total}"

    end

    #Make initial request, and look for 'next' token, and re-request until the 'next' token is no longer provided.
    def get_data(rule, start_time, end_time, tag=nil)

        next_token = 'first request'

        time_span = "#{start_time} to #{end_time}.  "
        if start_time.nil? and end_time.nil? then
            time_span = "last 30 days."
        elsif start_time.nil? then
            time_span = "30 days ago to #{end_time}. "
        elsif end_time.nil?
            time_span = "#{start_time} to now.  "
        end
        
        puts "Retrieving data from #{time_span}..."

        while !next_token.nil? do
            if next_token == 'first request' then
                next_token = nil
            end
            #puts "Next token: #{next_token}"
            next_token = make_data_request(rule, start_time, end_time, max_results, next_token, tag)
        end

    end #process_data

end #pt_stream class.