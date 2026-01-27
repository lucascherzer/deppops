{
  description = "deppops - A simple Rust web service";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, crane, flake-utils, advisory-db, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        craneLib = crane.mkLib pkgs;

        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;
          buildInputs = pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
          ];
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        deppops = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
          meta = with pkgs.lib; {
            description = "A simple Rust web service";
            homepage = "https://github.com/lucascherzer/deppops";
            license = with licenses; [ mit ];
            mainProgram = "deppops";
          };
        });
      in
      {
        packages = {
          default = deppops;
          inherit deppops;
          container = pkgs.dockerTools.buildImage {
            name = "deppops";
            tag = "latest";
            copyToRoot = deppops;
            config = {
              Cmd = [ "/bin/deppops" ];
            };
          };
        };

        apps.default = flake-utils.lib.mkApp {
          drv = deppops;
        };

        checks = {
          inherit deppops;
          deppops-test = craneLib.cargoTest (commonArgs // {
            inherit cargoArtifacts;
          });
          deppops-clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });
          deppops-fmt = craneLib.cargoFmt {
            inherit (commonArgs) src;
          };
          deppops-audit = craneLib.cargoAudit {
            inherit (commonArgs) src;
            inherit advisory-db;
          };
        };

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};
          packages = [
            pkgs.rust-analyzer
            pkgs.cargo-watch
            pkgs.cargo-edit
          ];
          RUST_LOG = "deppops=debug";
        };
      }
    );
}
