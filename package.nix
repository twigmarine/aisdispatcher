{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, aha
}:

stdenv.mkDerivation rec {
  pname = "aisdispatcher";
  version = "2.2";

  src = fetchurl {
    url = "https://www.aishub.net/downloads/dispatcher/packages/${version}/full.tar.bz2";
    sha256 = "1b7cf1df37e17d0b17d08830a08f6d5fb8faa0755bc4f327bbaf5993f8fc9a9a";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib  # Provides libgcc_s.so.1
  ];

  # Skip configure and build phases since this is a binary package
  dontConfigure = true;
  dontBuild = true;

  installPhase = let
    # Determine architecture-specific files to copy
    archConfig = {
      "x86_64-linux" = {
        binSuffix = "x86_64";
        libDir = "x86_64";
      };
      "aarch64-linux" = {
        binSuffix = "armv8_a72";
        libDir = "aarch64";
      };
      "armv7l-linux" = {
        binSuffix = "arm1176";
        libDir = "arm";
      };
      # Additional ARM variants - map to closest available binary?
      "armv6l-linux" = {
        binSuffix = "arm1176";  # arm1176 is ARMv6
        libDir = "arm";
      };
      "armv8l-linux" = {
        binSuffix = "armv8_a72";
        libDir = "aarch64";
      };
    };
    arch = archConfig.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
  in ''
    runHook preInstall
    
    # Create directory structure
    mkdir -p $out/{bin,lib,share/aisdispatcher}
    
    # Install only the binaries for current architecture
    cp bin/aiscontrol_${arch.binSuffix} $out/bin/aiscontrol
    cp bin/aisdispatcher_${arch.binSuffix} $out/bin/aisdispatcher
    # Skip check-for-updates - updates handled by NixOS
    
    # Install only the library for current architecture
    cp lib/${arch.libDir}/fake_tty.so $out/lib/
    
    # Install web interface and configuration (platform-independent)
    cp -r htdocs $out/share/aisdispatcher/
    cp -r etc $out/share/aisdispatcher/
    # Skip update_cache - updates handled by NixOS package manager
    
    # Make binaries executable
    chmod +x $out/bin/aiscontrol $out/bin/aisdispatcher
    
    # Wrap aiscontrol to include aha in PATH for web interface
    wrapProgram $out/bin/aiscontrol \
      --prefix PATH : ${lib.makeBinPath [ aha ]}
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "AIS Dispatcher - AIS data collection and distribution server";
    homepage = "https://www.aishub.net/";
    license = licenses.unfree; # Proprietary software
    platforms = [ "x86_64-linux" "aarch64-linux" "armv7l-linux" "armv6l-linux" ];
    maintainers = [ ]; # Add maintainer info if needed
  };
}