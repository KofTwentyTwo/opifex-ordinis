.PHONY: help pack validate clean lint dev publish-snapshot publish-release check-clean check-branch

ORB_NAME := kof22/opifex-ordinis
PACKED   := target/opifex-ordinis-packed.yml

help:
	@echo "Opifex Ordinis Orb Development Commands:"
	@echo ""
	@echo "  make pack              Pack the orb"
	@echo "  make validate          Pack + validate"
	@echo "  make lint              Run all linting checks"
	@echo "  make clean             Remove generated files"
	@echo "  make dev               Development workflow (pack, validate, status)"
	@echo "  make publish-snapshot  Publish dev:snapshot"
	@echo "  make publish-release   Publish tagged production release"

pack:
	@echo "Packing orb..."
	@mkdir -p ./target/
	@circleci orb pack src > $(PACKED)
	@echo "Packed: $(PACKED)"

validate: pack
	@echo "Validating packed orb..."
	@circleci orb validate $(PACKED)
	@echo "Validation passed"

lint:
	@echo "Running linting checks..."
	@echo ""
	@echo "1. YAML lint..."
	@yamllint src/commands/ src/jobs/ src/examples/ src/@orb.yml
	@echo "   YAML OK"
	@echo ""
	@echo "2. ShellCheck..."
	@shellcheck src/scripts/*.sh
	@echo "   ShellCheck OK"
	@echo ""
	@echo "3. CircleCI orb validate..."
	@circleci orb validate src/@orb.yml
	@echo "   Orb OK"
	@echo ""
	@echo "4. Orb pack + validate..."
	@circleci orb pack src > /tmp/oo-test-packed.yml
	@circleci orb validate /tmp/oo-test-packed.yml
	@rm -f /tmp/oo-test-packed.yml
	@echo "   Pack OK"
	@echo ""
	@echo "All linting checks passed."

clean:
	@rm -rf target
	@echo "Clean"

dev: validate
	@echo ""
	@echo "Development Status:"
	@echo "  Orb packed:     $(PACKED)"
	@echo "  Validation:     passed"
	@echo ""
	@echo "Next: make lint, then commit + push"

check-clean:
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Working directory not clean. Commit changes first."; \
		exit 1; \
	fi

check-branch:
	@current=$$(git branch --show-current); \
	if [ "$$current" != "main" ] && [ "$$current" != "develop" ]; then \
		echo "Warning: on branch '$$current', not main/develop"; \
		read -p "Continue? [y/N]: " confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then exit 1; fi; \
	fi

publish-snapshot: check-clean lint clean validate
	@echo "Publishing $(ORB_NAME)@dev:snapshot..."
	@read -p "Continue? [y/N]: " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then echo "Cancelled"; exit 1; fi; \
	circleci orb publish $(PACKED) $(ORB_NAME)@dev:snapshot; \
	echo "Snapshot published"

publish-release: check-clean check-branch lint clean validate
	@latest=$$(git tag -l 'v*' | sort -V | tail -1); \
	if [ -n "$$latest" ]; then \
		echo "Latest: $$latest"; \
		next=$$(echo "$$latest" | sed 's/^v//' | awk -F. '{$$NF++; print $$1"."$$2"."$$NF}'); \
	else \
		echo "No previous versions. Starting with v0.1.0"; \
		next="0.1.0"; \
	fi; \
	read -p "Version [v$$next]: " version; \
	version=$${version:-v$$next}; \
	echo "Creating tag $$version..."; \
	git tag -a "$$version" -m "Release $$version"; \
	circleci orb publish $(PACKED) $(ORB_NAME)@$$(echo $$version | sed 's/^v//'); \
	git push origin "$$version"; \
	echo "Released $$version"
