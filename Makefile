# Makefile for PodLoad-Mac
# 
# This Makefile provides convenient commands for building, running, and testing
# the PodLoad-Mac application.

.PHONY: build run test clean help

# Default target
all: build

# Build the application
build:
	@echo "Building PodLoad-Mac..."
	xcodebuild -project PodcastDownloader.xcodeproj -scheme PodcastDownloader -destination 'platform=macOS' -configuration Debug build

# Run the application
run: build
	@echo "Running PodLoad-Mac..."
	open -a PodcastDownloader

# Build and run for development
dev: build
	@echo "Opening in Xcode..."
	open PodcastDownloader.xcodeproj

# Run tests
test:
	@echo "Running tests..."
	xcodebuild test -project PodcastDownloader.xcodeproj -scheme PodcastDownloader -destination 'platform=macOS'

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	xcodebuild clean -project PodcastDownloader.xcodeproj -scheme PodcastDownloader
	rm -rf build/

# Show help
help:
	@echo "Available commands:"
	@echo "  build  - Build the application"
	@echo "  run    - Build and run the application"
	@echo "  dev    - Open project in Xcode"
	@echo "  test   - Run unit tests"
	@echo "  clean  - Clean build artifacts"
	@echo "  help   - Show this help message"
