#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'sqlite3'
require 'time'
require 'csv'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

INTERVAL_SEC = (ENV['INTERVAL_SEC'] || '5').to_i
DURATION_MIN = (ENV['DURATION_MIN'] || '10').to_f
API_URL = ENV['API_URL'] || 'https://qa-challenge-nine.vercel.app/api/name-checker'
DB_PATH = ENV['DB_PATH'] || 'request_logs.db'
def init_database(db_path)
  db = SQLite3::Database.new(db_path)
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS request_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        name_parameter TEXT NOT NULL,
        response_status INTEGER NOT NULL,
        response_text TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  SQL
  db
end

def load_names(filename)
  names = []
  CSV.foreach(filename, headers: true, encoding: 'UTF-8') do |row|
    names << row['name']
  end
  names
rescue => e
  puts "Warning: Could not load CSV file #{filename}: #{e.message}"
  []
end

def make_request(name, url)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  http.read_timeout = 10

  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = { name: name }.to_json

  begin
    response = http.request(request)
    {
      status: response.code.to_i,
      body: response.body,
      error: nil
    }
  rescue => e
    {
      status: 0,
      body: "Request failed: #{e.message}",
      error: e.message
    }
  end
end

def log_request(db, url, name, status, body)
  truncated_body = body.length > 1000 ? body[0, 1000] + "..." : body
  
  db.execute(
    "INSERT INTO request_logs (url, name_parameter, response_status, response_text) VALUES (?, ?, ?, ?)",
    [url, name, status, truncated_body]
  )
end

def start_monitoring
  puts "Starting QA monitoring..."
  puts "API URL: #{API_URL}"
  puts "Duration: #{DURATION_MIN} minutes"
  puts "Interval: #{INTERVAL_SEC} seconds"
  puts "Database: #{DB_PATH}"
  puts "-" * 50

  db = init_database(DB_PATH)
  names = load_names('data/seed_names.csv')
  
  if names.empty?
    puts "Warning: No names loaded from seed file"
    names = ['TestName']
  end

  start_time = Time.now
  end_time = start_time + (DURATION_MIN * 60)
  request_count = 0
  
  while Time.now < end_time
    name = names[request_count % names.length]
    
    puts "#{Time.now.strftime('%H:%M:%S')} - Testing name: '#{name.force_encoding('UTF-8')}'"
    
    result = make_request(name, API_URL)
    log_request(db, API_URL, name, result[:status], result[:body])
    
    status_symbol = result[:status] == 200 ? "✓" : "✗"
    puts "  #{status_symbol} Status: #{result[:status]} - #{result[:body].force_encoding('UTF-8')[0, 50]}"
    
    request_count += 1
    
    # Sleep until next interval (unless we're at the end)
    sleep(INTERVAL_SEC) if Time.now + INTERVAL_SEC < end_time
  end
  
  db.close
  puts "\nMonitoring completed!"
  puts "Total requests made: #{request_count}"
  puts "Duration: #{'%.1f' % ((Time.now - start_time) / 60)} minutes"
end

# Run if called directly
if __FILE__ == $0
  start_monitoring
end 