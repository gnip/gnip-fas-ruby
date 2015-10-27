#Prototype for converting FAS counts payloads to CSV/plots.
#Currently does no temporal binning, but it probably should.

#First use-case
#Counts for a single rule for any period.
#Default bucket: day
# CSV format: timePeriod, count

#{"results":[{"timePeriod":"200707120000","count":0},{"timePeriod":"200707110000","count":0}

class CountsToCSV

  attr_accessor :output, :bucket,
                :counts_hash
end

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.
  
  require 'csv'
  require 'json'
  require 'rake'
  
  outbox = "../output"
  bucket = 'day' 
  
  counts_hash = {}
  files = []
  files = FileList.new("#{outbox}/*.json")
  

  #iterate through each file in folder 
  files.each do |file|
    #puts file
    
    counts_json_file = File.open(file)
    
    counts_json = File.read(counts_json_file)
    
    #puts counts_json

    #Parse JSON to Hash, while re-formatting timestamp.
    hash = {}
    hash = JSON.parse(counts_json)
    
    counts = hash['results']

    counts.each do |count|
      counts_hash[count['timePeriod']] = count['count']
    end

  end
  
  #Write total hash to CSV file.
  #puts counts_hash

  csv_filename = "counts_#{bucket}.csv"
  csv_file = File.open(csv_filename, "w")
  csv_file.puts "Date,Counts"
  
  counts_hash.each do |count|
    csv_file.puts "#{count[0][0..3]}-#{count[0][4..5]}-#{count[0][6..7]},#{count[1]}"
  end

  csv_file.close #Close new CSV file.

end