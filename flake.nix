{
  description = "gRPC Swift 2 development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    grpc-swift-protobuf.url = "github:grpc/grpc-swift-protobuf/2.0.0";
    grpc-swift-protobuf.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      grpc-swift-protobuf,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      mkSwift6 = { pkgs, system }: import ./swift6/default.nix { inherit pkgs system; };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          swift = mkSwift6 { inherit pkgs system; };

          buildScript = pkgs.writeScriptBin "build-grpc-swift-protobuf" ''
            #!${pkgs.bash}/bin/bash
            PROJECT_ROOT="$(pwd)"
            while [[ "$PROJECT_ROOT" != "/" && ! -f "$PROJECT_ROOT/flake.nix" ]]; do
              PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
            done
            if [[ "$PROJECT_ROOT" == "/" ]]; then
              echo "❌ Could not find project root (no flake.nix found)"
              exit 1
            fi
            cd "$PROJECT_ROOT"
            exec ./scripts/build-grpc-swift-protobuf.sh
          '';

          checkScript = pkgs.writeScriptBin "check-grpc-plugin" ''
            #!${pkgs.bash}/bin/bash
            for path in "./grpc-swift-protobuf/.build/release/protoc-gen-grpc-swift-2" "./.bin/protoc-gen-grpc-swift-2"; do
              if [ -x "$path" ]; then
                echo "✅ Found: $path"
                exit 0
              fi
            done
            echo "❌ protoc-gen-grpc-swift-2 not found. Run: build-grpc-swift-protobuf"
            exit 1
          '';
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              swift
              pkgs.protobuf
              pkgs.protoc-gen-swift
              pkgs.git
              buildScript
              checkScript
            ];
            shellHook = ''
              echo "🚀 gRPC Swift 2 environment ready"
              echo ""
              echo "Commands:"
              echo "  build-grpc-swift-protobuf  # Build grpc-swift-protobuf"
              echo "  check-grpc-plugin          # Check plugin status"
              echo "  nix run .#codegen          # Generate code"
              echo ""
            '';
          };
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;

          codegenScript = pkgs.writeScriptBin "grpc-codegen" ''
            #!${pkgs.bash}/bin/bash
            set -eo pipefail

            PROTO_DIR=""
            OUTPUT_DIR="generated"
            PROTO_FILES=()

            while [[ $# -gt 0 ]]; do
              case $1 in
                -p|--proto-dir) PROTO_DIR="$2"; shift 2 ;;
                -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
                -h|--help)
                  echo "Usage: nix run .#codegen -- [OPTIONS] <proto-files>"
                  echo "  -p, --proto-dir DIR    Proto directory"
                  echo "  -o, --output-dir DIR   Output directory (default: generated)"
                  echo "  -h, --help            Show help"
                  exit 0 ;;
                -*) echo "Unknown option: $1"; exit 1 ;;
                *) PROTO_FILES+=("$1"); shift ;;
              esac
            done

            [ ''${#PROTO_FILES[@]} -eq 0 ] && echo "No proto files specified" && exit 1

            # Find plugin
            for path in "./grpc-swift-protobuf/.build/release/protoc-gen-grpc-swift-2" "./.bin/protoc-gen-grpc-swift-2"; do
              if [ -x "$path" ]; then
                PLUGIN_PATH="$path"
                break
              fi
            done

            [ -z "''${PLUGIN_PATH:-}" ] && echo "❌ protoc-gen-grpc-swift-2 not found. Run: nix develop && build-grpc-swift-protobuf" && exit 1

            [ -z "$PROTO_DIR" ] && PROTO_DIR=$(dirname "''${PROTO_FILES[0]}")
            mkdir -p "$OUTPUT_DIR"

            for proto_file in "''${PROTO_FILES[@]}"; do
              ${pkgs.protobuf}/bin/protoc --proto_path="$PROTO_DIR" --plugin=protoc-gen-swift=${pkgs.protoc-gen-swift}/bin/protoc-gen-swift --swift_out="$OUTPUT_DIR" "$proto_file"
              ${pkgs.protobuf}/bin/protoc --proto_path="$PROTO_DIR" --plugin="$PLUGIN_PATH" --grpc-swift-2_out="$OUTPUT_DIR" "$proto_file"
            done

            echo "✅ Generated files in $OUTPUT_DIR"
          '';

          buildCommand = pkgs.writeScriptBin "build-grpc-swift-protobuf" ''
            #!${pkgs.bash}/bin/bash
            PROJECT_ROOT="$(pwd)"
            while [[ "$PROJECT_ROOT" != "/" && ! -f "$PROJECT_ROOT/flake.nix" ]]; do
              PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
            done
            if [[ "$PROJECT_ROOT" == "/" ]]; then
              echo "❌ Could not find project root (no flake.nix found)"
              exit 1
            fi
            cd "$PROJECT_ROOT"
            exec ./scripts/build-grpc-swift-protobuf.sh
          '';
        in
        {
          codegen = {
            type = "app";
            program = "${codegenScript}/bin/grpc-codegen";
          };
          build = {
            type = "app";
            program = "${buildCommand}/bin/build-grpc-swift-protobuf";
          };
        }
      );
    };
}
