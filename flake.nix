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
            tag = self.shortRev or "dirty";
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
          # Kubernetes manifest linting
          deppops-kubeconform = pkgs.runCommand "deppops-kubeconform" {
            nativeBuildInputs = [ pkgs.kubeconform ];
            src = self;
          } ''
            set -e
            cd $src
            kubeconform k8s/
            touch $out
          '';


          # SAST scanning with semgrep
          deppops-semgrep = pkgs.runCommand "deppops-semgrep" {
            nativeBuildInputs = [ pkgs.semgrep pkgs.cacert ];
            src = commonArgs.src;
            SEMGREP_DISABLE_TELEMETRY = "1";
            # We set $HOME here because semgrep will try to create a directory
            # there. It cant do that in the $out dir (which is what this script
            # operates in) because it is sandboxed
            HOME = "/tmp/semgrep-home";
          } ''
            cd $src
            # Run semgrep with auto config (includes Rust security rules)
            # --error: Exit with error code if findings
            # --quiet: Reduce noise
            # --exclude: Skip test files and generated code
            semgrep scan \
              --config=auto \
              --error \
              --quiet \
              --exclude='tests/' \
              --exclude='target/' \
              .
              touch $out
          '';

        };

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};
          packages = with pkgs; [
            # this includes all dependencies we need in CI, so our local env
            # and CI always matches - no env mismatch caused errors
            rust-analyzer
            cargo-watch
            cargo-edit
            syft
            grype
            nushell
            cosign
            skopeo
            semgrep
            kubeconform
          ];
          RUST_LOG = "deppops=debug";
        };
      }
    );
}
