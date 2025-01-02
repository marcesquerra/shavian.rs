rec {
  description = "shavian.rs flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    bacon-src = {
      url = "github:Canop/bacon"; 
      flake = false;
    };
    crane = {
      url = "github:ipetkov/crane/v0.20.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-analyzer-src = rec {
      url = "github:rust-lang/rust-analyzer/2024-12-30"; 
      flake = false;
    };
    cargo-watch-src = {
      url = "github:watchexec/cargo-watch/8.x"; 
      flake = false;
    };

  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, bacon-src, crane, rust-analyzer-src, cargo-watch-src, ... }:

    flake-utils.lib.eachDefaultSystem (system:

      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        craneLib = crane.mkLib pkgs;
        rustChannel = (pkgs.rust-bin.stable."1.83.0");
        rustPackage = rustChannel.default;
        rust-src = rustChannel.rust-src;
        rust-analyzer = cargoInstall rust-analyzer-src {
          pname = "rust-analyzer";
          version = "from-flake";
          doCheck = false;
        };
        cargoInstall = pkg-src : extra-options :
          craneLib.buildPackage ({
            src = craneLib.cleanCargoSource pkg-src;
          } // extra-options);
        bacon = cargoInstall bacon-src {};
        cargo-watch = cargoInstall cargo-watch-src {
          doCheck = false;
        };
        md2shv-package = craneLib.buildPackage {
          src = craneLib.cleanCargoSource (craneLib.path ./.);

          # Tests currently need to be run via `cargo wasi` which
          # isn't packaged in nixpkgs yet...
          doCheck = false;

          buildInputs = [
            # Add additional build inputs here
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];
        };
        carapace-spec = pkgs.runCommand "carapace-spec" {} ''
          ${md2shv-package}/bin/md2shv gen-completer carapace > $out
        '';
      in {
        checks = {
          md2shv = md2shv-package;
        };
        apps = rec {
          md2shv = flake-utils.lib.mkApp { drv = md2shv-package; };
          default = md2shv;
        };
        packages = rec {
          inherit carapace-spec;
          md2shv = md2shv-package;
          default = md2shv;
        };
        devShells.default = import ./nix/flake-shell.nix {
          inherit rustPackage rust-src cargo-watch bacon rust-analyzer;
          packages = pkgs;
        };
      }
    );  
}
