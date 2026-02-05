#!/usr/bin/env nu
# Generate vulnerability reports from the container image
# Returns the reports directory path
def main [] {
    let reports_dir = (mktemp -d)

    # Resolve the result symlink to absolute path
    let container_path = (readlink -f result)

    # Decompress the .tar.gz to plain .tar for syft/grype
    let container_tar = $"($reports_dir)/container.tar"
    gunzip -c $container_path | save -f $container_tar

    # Generate SBOM with syft
    syft -o spdx-json $"docker-archive:($container_tar)" | save -f $"($reports_dir)/sbom.spdx.json"

    # Scan for vulnerabilities with grype
    grype -o cyclonedx-json $"docker-archive:($container_tar)" | save -f $"($reports_dir)/cve.cyclonedx.json"

    # Return the reports directory path (only output to stdout)
    print $reports_dir
}
