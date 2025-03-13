#!/bin/bash
set -e

# First make scripts executable
chmod +x scripts/build.sh

# Build everything
./scripts/build.sh

# Start Swift service
./swift/.build/release/AudioControl &
SWIFT_PID=$!

# Start Go application
./bin/mac-volume-mixer

# Cleanup
kill $SWIFT_PID