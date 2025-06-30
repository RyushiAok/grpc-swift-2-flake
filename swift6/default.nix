# Swift 6.1 binary builder - Optimized version
{ pkgs, system }:
let
  version = "6.1";
  isDarwin = pkgs.stdenv.isDarwin;

  # ref: https://github.com/timothyklim/swift-flake/blob/master/flake.nix
  swiftUrls = {
    "x86_64-linux" = {
      url = "https://download.swift.org/swift-6.1-release/ubuntu2404/swift-6.1-RELEASE/swift-6.1-RELEASE-ubuntu24.04.tar.gz";
      sha256 = pkgs.lib.fakeHash;
    };
    "aarch64-linux" = {
      url = "https://download.swift.org/swift-6.1-release/ubuntu2404-aarch64/swift-6.1-RELEASE/swift-6.1-RELEASE-ubuntu24.04-aarch64.tar.gz";
      sha256 = pkgs.lib.fakeHash;
    };
    "x86_64-darwin" = {
      url = "https://download.swift.org/swift-6.1-release/xcode/swift-6.1-RELEASE/swift-6.1-RELEASE-osx.pkg";
      sha256 = "sha256-pwLRl2xlo85HGKEByzxF8RyW0WEYU2ZsL0XbpSPz0WU=";
    };
    "aarch64-darwin" = {
      url = "https://download.swift.org/swift-6.1-release/xcode/swift-6.1-RELEASE/swift-6.1-RELEASE-osx.pkg";
      sha256 = "sha256-pwLRl2xlo85HGKEByzxF8RyW0WEYU2ZsL0XbpSPz0WU=";
    };
  };

  swiftBinary = swiftUrls.${system} or (throw "Unsupported system: ${system}");

  linuxBuildInputs = with pkgs; [
    stdenv.cc.cc
    libxml2
    libedit
    sqlite
    icu
    libuuid
    ncurses
    zlib
    curl
  ];

in
if isDarwin then
  pkgs.stdenv.mkDerivation {
    pname = "swift";
    inherit version;
    src = pkgs.fetchurl { inherit (swiftBinary) url sha256; };

    nativeBuildInputs = with pkgs; [
      xar
      gzip
      cpio
    ];

    unpackPhase = ''
      xar -xf $src
      cd swift-*.pkg
      cat Payload | gunzip -dc | cpio -i
      cd ..
    '';

    installPhase = ''
      mkdir -p $out
      if [ -d "swift-6.1-RELEASE-osx-package.pkg/usr" ]; then
        cp -r swift-6.1-RELEASE-osx-package.pkg/usr/* $out/
      elif [ -d "usr" ]; then
        cp -r usr/* $out/
      else
        exit 1
      fi
      chmod +x $out/bin/* 2>/dev/null || true
    '';

    meta = with pkgs.lib; {
      description = "Swift 6.1 - macOS binary";
      homepage = "https://swift.org";
      license = licenses.asl20;
      platforms = platforms.darwin;
    };
  }
else
  pkgs.stdenv.mkDerivation {
    pname = "swift";
    inherit version;
    src = pkgs.fetchurl { inherit (swiftBinary) url sha256; };

    nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
    buildInputs = linuxBuildInputs;

    installPhase = ''
      mkdir -p $out
      cp -r usr/* $out/
      chmod +x $out/bin/*
      find $out -type f -executable -exec file {} \; | \
        grep -E "(dynamically linked|shared object)" | \
        cut -d: -f1 | \
        xargs -r -n1 patchelf --set-rpath "${pkgs.lib.makeLibraryPath linuxBuildInputs}:$out/lib"
    '';

    meta = with pkgs.lib; {
      description = "Swift 6.1 - Linux binary";
      homepage = "https://swift.org";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  }
