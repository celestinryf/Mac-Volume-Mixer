#!/bin/bash
set -e

echo "Building Swift audio controller..."
cd swift
swift build -c release

echo "Building Go application..."
cd ..
go build -o bin/mac-volume-mixer ./cmd/mac-volume-mixer

echo "Build complete!"