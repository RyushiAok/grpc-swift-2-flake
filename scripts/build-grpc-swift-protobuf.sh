#!/usr/bin/env bash

# grpc-swift-protobuf自動ビルドスクリプト
# このスクリプトは煩雑な手動ビルドを自動化します

set -euo pipefail

# Project root
cd "$(dirname "$0")/.."

# Clone grpc-swift-protobuf if it doesn't exist
if [ ! -d "grpc-swift-protobuf" ]; then
    echo "Cloning grpc-swift-protobuf..."
    git clone -b 2.0.0 --depth 1 https://github.com/grpc/grpc-swift-protobuf.git
fi

cd grpc-swift-protobuf

# Build
echo "Building protoc-gen-grpc-swift-2..."
swift build -c release --product protoc-gen-grpc-swift-2

# Verify build
if [ ! -f ".build/release/protoc-gen-grpc-swift-2" ]; then
    echo "❌ Build failed"
    exit 1
fi

# Copy to bin directory
mkdir -p ../.bin
cp .build/release/protoc-gen-grpc-swift-2 ../.bin/
chmod +x ../.bin/protoc-gen-grpc-swift-2

echo "✅ protoc-gen-grpc-swift-2 built successfully" 