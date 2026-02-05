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
    semgrep-rules = {
      url = "github:semgrep/semgrep-rules";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, crane, flake-utils, advisory-db, semgrep-rules, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        craneLib = crane.mkLib pkgs;

        # Kubernetes version for schema validation
        k8sVersion = "v1.31.0";

        # Download only the specific schema files we need from raw.githubusercontent.com
        # This avoids downloading the entire 2GB+ repo
        k8sSchemaBase = "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/${k8sVersion}-standalone";

        # To get the correct hash:
        # 1. Set sha256 = pkgs.lib.fakeHash (or leave as-is on first run)
        # 2. Run: nix build .#checks.x86_64-linux.deppops-kubeconform
        # 3. Nix will fail and show the actual hash
        # 4. Replace pkgs.lib.fakeHash with the actual hash shown in the error
        #
        # To add more schemas (e.g., for Deployment, Service, etc.):
        # 1. Add a new fetchurl for each resource type
        # 2. Add a cp line in k8sSchemas runCommand below
        namespaceSchema = pkgs.fetchurl {
          url = "${k8sSchemaBase}/namespace-v1.json";
          sha256 = "sha256-1AA3lrGujDvcnDye2TiW1z0f0tzX6p55kG6Us8ouPHQ=";
        };

        # Create a directory with all schemas we need
        k8sSchemas = pkgs.runCommand "k8s-schemas" {} ''
          mkdir -p $out
          cp ${namespaceSchema} $out/namespace-v1.json
        '';

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
            # Use local kubernetes schemas to avoid network access in Nix sandbox
            kubeconform \
              -schema-location '${k8sSchemas}/{{ .ResourceKind }}{{ .KindSuffix }}.json' \
              -summary \
              k8s/
            touch $out
          '';


          # SAST scanning with semgrep
          deppops-semgrep = pkgs.runCommand "deppops-semgrep" {
            nativeBuildInputs = [ pkgs.semgrep pkgs.findutils pkgs.cacert ];
            src = commonArgs.src;
            SEMGREP_DISABLE_TELEMETRY = "1";
            HOME = "$TMPDIR";
          } ''
            export HOME=$TMPDIR
            cd $src

            # Find all Rust rule files in the semgrep-rules repo
            # This automatically includes all Rust security, best-practice, and correctness rules
            RUST_RULES=$(find ${semgrep-rules}/rust -name '*.yaml' -o -name '*.yml' | tr '\n' ' ')

            # Run semgrep with local rules to avoid network access in Nix sandbox
            # --error: Exit with error code if findings
            # --quiet: Reduce noise
            # --exclude: Skip test files and generated code
            semgrep scan \
              --config $RUST_RULES \
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
