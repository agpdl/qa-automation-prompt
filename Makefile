RUBY = ruby

.PHONY: help
help:
	@echo "QA Automation Challenge - Available Commands:"
	@echo ""
	@echo "Monitoring:"
	@echo "  make monitor         - Run API monitoring (10 min, 1s intervals)"
	@echo "  make uptime          - Calculate service uptime from database"
	@echo "  make dashboard       - Generate dynamic HTML dashboard from database"
	@echo "  make run-full        - Full cycle: monitor + generate dashboard"
	@echo "  make reproduce-bug   - Test the 'example' domain bug patterns"
	@echo "  make clean           - Clear database (start fresh)"
	@echo ""

	@echo "Environment variables:"
	@echo "  WINDOW_SEC     - Uptime time window (default: 60)"

.PHONY: monitor
monitor:
	INTERVAL_SEC=1 DURATION_MIN=10 $(RUBY) scripts/monitor.rb

.PHONY: uptime
uptime:
	WINDOW_SEC=60 $(RUBY) scripts/uptime.rb

.PHONY: clean
clean:
	@echo "Clearing database..."
	@rm -f request_logs.db
	@echo "Database cleared!"

.PHONY: dashboard
dashboard:
	@echo "Generating dynamic dashboard..."
	@$(RUBY) scripts/generate_dashboard.rb

.PHONY: run-full
run-full:
	@echo "Running full monitoring cycle..."
	@$(MAKE) monitor
	@$(MAKE) dashboard
	@echo "Monitoring complete! Dashboard updated with fresh data."

.PHONY: reproduce-bug
reproduce-bug:
	@$(RUBY) scripts/reproduce_example_domain_bug.rb

