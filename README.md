# grpc-swift-2-flake

> [!NOTE]
> This is a naive gRPC Swift 2 support until nixpkgs officially supports Swift 6.

A Nix flake for gRPC Swift 2.0 development environment using locally built `grpc-swift-protobuf`.

## Usage

```bash
# Enter development environment
nix develop

# Build gRPC Swift 2 plugin
build-grpc-swift-protobuf

# Check plugin status
check-grpc-plugin

# Generate code
nix run .#codegen -- -o ./.out/generated examples/proto/*.proto
```
