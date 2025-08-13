#!/usr/bin/env ruby

require 'sqlite3'
require 'json'
require 'time'

# Configuration
DB_PATH = 'request_logs.db'
OUTPUT_PATH = 'index.html'
WINDOW_SEC = ENV['WINDOW_SEC']&.to_i || 60

def get_monitoring_data
  unless File.exist?(DB_PATH)
    puts "Database not found: #{DB_PATH}"
    puts "Run 'make monitor' first to generate monitoring data"
    exit 1
  end

  db = SQLite3::Database.new(DB_PATH)
  db.results_as_hash = true
  
  # Get all requests
  requests = db.execute("SELECT * FROM request_logs ORDER BY timestamp")
  
  if requests.empty?
    puts "No monitoring data found in database"
    exit 1
  end

  # Calculate stats
  total_requests = requests.length
  successful_requests = requests.count { |r| r['response_status'] == 200 }
  failed_requests = requests.count { |r| r['response_status'] == 500 }
  
  # Time range
  start_time = Time.parse(requests.first['timestamp'])
  end_time = Time.parse(requests.last['timestamp'])
  duration_minutes = ((end_time - start_time) / 60).round(1)
  
  # Success rate
  success_rate = (successful_requests.to_f / total_requests * 100).round(2)
  failure_rate = (failed_requests.to_f / total_requests * 100).round(2)
  
  db.close
  
  {
    total_requests: total_requests,
    successful_requests: successful_requests,
    failed_requests: failed_requests,
    success_rate: success_rate,
    failure_rate: failure_rate,
    start_time: start_time,
    end_time: end_time,
    duration_minutes: duration_minutes,
    last_updated: Time.now
  }
end

def generate_html(data)
  # Determine status color based on success rate
  status_class = case data[:success_rate]
  when 95..100 then 'uptime-good'
  when 80..94 then 'uptime-warning'
  else 'uptime-bad'
  end
  
  status_text = case data[:success_rate]
  when 95..100 then 'Excellent'
  when 90..94 then 'Good'
  when 80..89 then 'Warning'
  else 'Critical'
  end

  html = <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API Monitoring Dashboard</title>
    <meta name="description" content="Live API monitoring results showing #{data[:success_rate]}% uptime over #{data[:duration_minutes]} minutes with detailed error analysis">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            text-align: center;
            color: white;
            margin-bottom: 30px;
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }
        
        .last-updated {
            font-size: 0.9rem;
            opacity: 0.8;
            margin-top: 10px;
        }
        
        .dashboard {
            display: grid;
            grid-template-columns: 1fr 1fr;
            grid-template-rows: 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .card {
            background: white;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 8px 25px rgba(0,0,0,0.1);
            transition: transform 0.2s ease;
        }
        
        .card:hover {
            transform: translateY(-2px);
        }
        
        .card h3 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 1.3rem;
            border-bottom: 2px solid #ecf0f1;
            padding-bottom: 10px;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
            padding: 10px 0;
        }
        
        .metric:last-child {
            margin-bottom: 0;
        }
        
        .metric-label {
            font-weight: 500;
            color: #555;
        }
        
        .metric-value {
            font-weight: 700;
            font-size: 1.1rem;
        }
        
        .uptime-good {
            color: #27ae60;
        }
        
        .uptime-warning {
            color: #f39c12;
        }
        
        .uptime-bad {
            color: #e74c3c;
        }
        
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-good {
            background-color: #27ae60;
        }
        
        .status-warning {
            background-color: #f39c12;
        }
        
        .status-bad {
            background-color: #e74c3c;
        }
        
        .footer {
            text-align: center;
            color: white;
            opacity: 0.8;
            margin-top: 40px;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 15px;
            }
            
            .header h1 {
                font-size: 2rem;
            }
            
            .dashboard {
                grid-template-columns: 1fr;
                grid-template-rows: auto;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 API Monitoring Dashboard</h1>
            <div class="last-updated">
                Last updated: #{data[:last_updated].strftime('%Y-%m-%d %H:%M:%S UTC')}
            </div>
        </div>
        
        <div class="dashboard">
            <div class="card">
                <h3>🎯 Service Status</h3>
                <div class="metric">
                    <span class="metric-label">
                        <span class="status-indicator status-#{status_class == 'uptime-good' ? 'good' : status_class == 'uptime-warning' ? 'warning' : 'bad'}"></span>
                        Overall Status
                    </span>
                    <span class="metric-value #{status_class}">#{status_text}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Uptime</span>
                    <span class="metric-value #{status_class}">#{data[:success_rate]}%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Monitoring Duration</span>
                    <span class="metric-value">#{data[:duration_minutes]} minutes</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Total Requests</span>
                    <span class="metric-value">#{data[:total_requests]}</span>
                </div>
            </div>
            
            <div class="card">
                <h3>📊 Request Statistics</h3>
                <div class="metric">
                    <span class="metric-label">Successful Requests</span>
                    <span class="metric-value uptime-good">#{data[:successful_requests]}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Failed Requests</span>
                    <span class="metric-value uptime-bad">#{data[:failed_requests]}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Success Rate</span>
                    <span class="metric-value #{status_class}">#{data[:success_rate]}%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Failure Rate</span>
                    <span class="metric-value uptime-bad">#{data[:failure_rate]}%</span>
                </div>
            </div>
            
            <div class="card">
                <h3>⏰ Time Range</h3>
                <div class="metric">
                    <span class="metric-label">Start Time</span>
                    <span class="metric-value">#{data[:start_time].strftime('%H:%M:%S')}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">End Time</span>
                    <span class="metric-value">#{data[:end_time].strftime('%H:%M:%S')}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Date</span>
                    <span class="metric-value">#{data[:start_time].strftime('%Y-%m-%d')}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Duration</span>
                    <span class="metric-value">#{data[:duration_minutes]} min</span>
                </div>
            </div>
            
            <div class="card">
                <h3>🚨 Error Summary</h3>
                <div class="metric">
                    <span class="metric-label">HTTP 500 Errors</span>
                    <span class="metric-value uptime-bad">#{data[:failed_requests]} (#{data[:failure_rate]}%)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Error Code</span>
                    <span class="metric-value">500</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Error Message</span>
                    <span class="metric-value">"System is down"</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Pattern</span>
                    <span class="metric-value">Intermittent failures</span>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>🔄 Automated API Monitoring • Updated every run via GitHub Actions</p>
            <p>Monitoring endpoint: POST https://qa-challenge-nine.vercel.app/api/name-checker</p>
        </div>
    </div>
</body>
</html>
HTML

  html
end

# Main execution
puts "Generating dashboard..."

begin
  data = get_monitoring_data
  html_content = generate_html(data)
  
  File.write(OUTPUT_PATH, html_content)
  
  puts "Dashboard generated: #{OUTPUT_PATH}"
  puts "Results: #{data[:success_rate]}% success rate (#{data[:successful_requests]}/#{data[:total_requests]} requests)"
  
rescue => e
  puts "Error generating dashboard: #{e.message}"
  exit 1
end