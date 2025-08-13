#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

API_URL = 'https://qa-challenge-nine.vercel.app/api/name-checker'

def test_bug_pattern(name, retries = 3)
  retries.times do |attempt|
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req.body = { name: name }.to_json
    
    res = http.request(req)
    status = res.code.to_i
    body = res.body
    
    if status == 500 && body.include?("Unexpected server error")
      puts "🚨 #{name.ljust(30)} → BUG REPRODUCED"
      return true
    elsif status == 500 && body.include?("System is down")
      if attempt < retries - 1
        sleep 0.5
        next
      else
        puts "⚠️  #{name.ljust(30)} → Intermittent error (after #{retries} attempts)"
      end
    elsif status == 200
      puts "✅ #{name.ljust(30)} → Success"
      return false
    else
      puts "❓ #{name.ljust(30)} → Other (#{status})"
      return false
    end
  end
  
  false
rescue => e
  puts "❌ #{name.ljust(30)} → Error: #{e.message}"
  false
end

puts "🚨 NAME FORMATTING BUG - 'EXAMPLE' DOMAIN PATTERNS"
puts "="*70
puts "Bug: URLs containing 'example' in domain trigger server error"
puts "Error: HTTP 500 - {\"message\":\"Unexpected server error\"}"
puts "="*70

bug_patterns = [
  "https://example.com",
  "http://example.com",
  "http://example.org",
  "http://example.net", 
  "http://test.example",
  "http://example.test",
  "http://example.co",
  "http://example.io",
  "http://examples.com",
  "http://myexample.com", 
  "http://example123.com",
  "http://www.example.com",
  "http://api.example.com",
  "ftp://example.com",
  "http://example%2Ecom",
  "http%3A//example.com",
  "http://placeholder.com",
  "http://Example.Com",
]
puts "\n📍 BUG PATTERNS (should fail):"
bug_count = 0
bug_patterns.each do |pattern|
  if test_bug_pattern(pattern)
    bug_count += 1
  end
  sleep 0.1
end

puts "\n📍 NON-BUG PATTERNS (should work):"
non_bug_patterns = [
  "http://s.com",
  "http://test.com",
  "http://google.com",
  "http://EXAMPLE.COM",
  "file://example.com",
  "Ana",
]

non_bug_patterns.each do |pattern|
  test_bug_pattern(pattern)
  sleep 0.1
end

puts "\n" + "="*70
puts "SUMMARY:"
puts "  Bug reproduced: #{bug_count}/#{bug_patterns.length} patterns"
puts "  Success rate: #{(bug_count.to_f / bug_patterns.length * 100).round(1)}%"
puts

puts "🎯 REPRODUCTION COMMANDS:"
puts "curl -X POST 'https://qa-challenge-nine.vercel.app/api/name-checker' \\"
puts "  -H 'Content-Type: application/json' \\"
puts "  -d '{\"name\":\"https://example.com\"}'"
puts
puts "curl -X POST 'https://qa-challenge-nine.vercel.app/api/name-checker' \\"
puts "  -H 'Content-Type: application/json' \\"
puts "  -d '{\"name\":\"http://example.org\"}'"
puts

puts "📋 BUG ANALYSIS:"
puts "  Pattern: URLs containing 'example' (case-sensitive) in domain"
puts "  Trigger: Server-side URL validation/filtering logic"
puts "  Error: Unhandled exception during 'example' domain processing"
puts "  Protocols: HTTP, HTTPS, FTP (not file://, mailto:// etc.)"
puts "  Case: Lowercase 'example' triggers bug, 'EXAMPLE' works fine" 