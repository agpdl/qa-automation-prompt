#!/usr/bin/env ruby

require 'sqlite3'
require 'time'

DB_PATH = ENV['DB_PATH'] || 'request_logs.db'
WINDOW_SEC = (ENV['WINDOW_SEC'] || '60').to_i

def calculate_request_uptime(db)
  total_requests = db.get_first_value("SELECT COUNT(*) FROM request_logs")
  successful_requests = db.get_first_value("SELECT COUNT(*) FROM request_logs WHERE response_status = 200")
  
  return 0.0, 0, 0 if total_requests == 0
  
  uptime_percentage = (successful_requests.to_f / total_requests.to_f) * 100
  
  [uptime_percentage, successful_requests, total_requests]
end

def calculate_time_uptime(db, window_sec)
  rows = db.execute("SELECT response_status, timestamp FROM request_logs ORDER BY timestamp")
  return 0.0, 0, 0 if rows.empty?
  
  windows = {}
  
  rows.each do |status, timestamp_str|
    timestamp = Time.parse(timestamp_str)
    window_start = (timestamp.to_i / window_sec) * window_sec
    window_key = Time.at(window_start)
    
    windows[window_key] ||= { total: 0, successful: 0 }
    windows[window_key][:total] += 1
    windows[window_key][:successful] += 1 if status == 200
  end
  
  # Count windows as "up" if they have at least one successful request
  up_windows = 0
  total_windows = windows.size
  
  windows.each do |window_time, stats|
    up_windows += 1 if stats[:successful] > 0
  end
  
  uptime_percentage = total_windows > 0 ? (up_windows.to_f / total_windows.to_f) * 100 : 0.0
  
  [uptime_percentage, up_windows, total_windows]
end

def get_error_summary(db)
  error_counts = {}
  
  rows = db.execute("SELECT response_status, COUNT(*) as count FROM request_logs WHERE response_status != 200 GROUP BY response_status ORDER BY count DESC")
  
  rows.each do |status, count|
    error_counts[status] = count
  end
  
  error_counts
end

def get_time_range(db)
  result = db.get_first_row("SELECT MIN(timestamp) as min_time, MAX(timestamp) as max_time, COUNT(*) as total FROM request_logs")
  return nil if result.nil? || result[2] == 0
  
  {
    start_time: Time.parse(result[0]),
    end_time: Time.parse(result[1]),
    total_requests: result[2]
  }
end

def calculate_uptime
  puts "QA Service Uptime Report"
  puts "Database: #{DB_PATH}"
  puts "Time Window: #{WINDOW_SEC} seconds"
  puts "=" * 50
  
  begin
    db = SQLite3::Database.new(DB_PATH)
    
    # Check if we have data
    time_range = get_time_range(db)
    if time_range.nil?
      puts "No data found in database. Run monitor.rb first."
      return
    end
    
    # Display data range
    duration_minutes = ((time_range[:end_time] - time_range[:start_time]) / 60.0)
    puts "Data Range:"
    puts "  Start: #{time_range[:start_time].strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  End:   #{time_range[:end_time].strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  Duration: #{'%.1f' % duration_minutes} minutes"
    puts "  Total Requests: #{time_range[:total_requests]}"
    puts

    # Calculate request-based uptime
    request_uptime, successful_requests, total_requests = calculate_request_uptime(db)
    puts "Uptime by Requests:"
    puts "  Successful: #{successful_requests} / #{total_requests}"
    puts "  Uptime: #{'%.2f' % request_uptime}%"
    puts
    
    # Calculate time-based uptime
    time_uptime, up_windows, total_windows = calculate_time_uptime(db, WINDOW_SEC)
    puts "Uptime by Time (#{WINDOW_SEC}s windows):"
    puts "  Up Windows: #{up_windows} / #{total_windows}"
    puts "  Uptime: #{'%.2f' % time_uptime}%"
    puts
    
    # Show error summary
    error_counts = get_error_summary(db)
    if error_counts.any?
      puts "Error Summary:"
      error_counts.each do |status, count|
        percentage = (count.to_f / total_requests.to_f) * 100
        puts "  HTTP #{status}: #{count} requests (#{'%.2f' % percentage}%)"
      end
      puts
    end
    
    # Summary
    puts "Summary:"
    puts "  Overall Request Success Rate: #{'%.2f' % request_uptime}%"
    puts "  Overall Time-based Uptime: #{'%.2f' % time_uptime}%"
    
    db.close
    
  rescue SQLite3::Exception => e
    puts "Database error: #{e.message}"
  rescue => e
    puts "Error: #{e.message}"
  end
end

# Run if called directly
if __FILE__ == $0
  calculate_uptime
end 