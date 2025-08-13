# QA Automation Challenge

Ruby scripts for monitoring API uptime and generating web dashboards. Monitors the QA Challenge API endpoint (`https://qa-challenge-nine.vercel.app/api/name-checker`) and includes GitHub Actions automation.

## Installation

**Prerequisites:**
- Ruby 2.6+ 
- Make utility (usually pre-installed on macOS/Linux, on Windows: `choco install make` or use WSL)

```bash
# Clone the repository
git clone https://github.com/agpdl/qa-automation-prompt.git
cd qa-automation-prompt

# Install Ruby dependencies
gem install sqlite3
```

## Bug Found

The API has a bug with URLs containing "example" in the domain name. These requests return HTTP 500 errors:

- `https://example.com`
- `http://example.org` 
- `http://myexample.com`

Test it:
```bash
curl -X POST 'https://qa-challenge-nine.vercel.app/api/name-checker' \
  -H 'Content-Type: application/json' \
  -d '{"name":"https://example.com"}'
```

## Usage

```bash
make monitor    # Run 10-minute monitoring
make uptime     # Show uptime stats
make dashboard  # Generate HTML dashboard
```

## Live Dashboard

Push to GitHub and enable GitHub Pages to see results at:
`https://agpdl.github.io/qa-automation-prompt/`

The dashboard shows uptime percentages, request counts, error summaries, and timestamps.

Manually trigger monitoring via GitHub Actions or run locally:
```bash
make run-full
```

## Files

- `scripts/monitor.rb` - Main monitoring script
- `scripts/uptime.rb` - Calculate uptime from database
- `scripts/generate_dashboard.rb` - Create HTML dashboard
- `data/seed_names.csv` - Test cases
- `request_logs.db` - SQLite database
- `index.html` - Dashboard (auto-generated)

