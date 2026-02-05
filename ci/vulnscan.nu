#!/usr/bin/env nu
# Generate vulnerability reports from the container image
# Returns the reports directory path
def main [] {
    let reports_dir = (mktemp -d)

    # Resolve the result symlink to absolute path
    let container_path = (readlink -f result)
    print $"Container path: ($container_path)"

    # Decompress the .tar.gz to plain .tar for syft/grype
    let container_tar = $"($reports_dir)/container.tar"
    print $"Decompressing to: ($container_tar)"
    gunzip -c $container_path | save -f $container_tar
    print "Decompressed successfully"

    # Generate SBOM with syft
    print "Generating SBOM with syft..."
    syft -o spdx-json $"docker-archive:($container_tar)" | save -f $"($reports_dir)/sbom.spdx.json"
    print "SBOM generated successfully"

    # Scan for vulnerabilities with grype
    print "Scanning for vulnerabilities with grype..."
    grype -o cyclonedx-json $"docker-archive:($container_tar)" | save -f $"($reports_dir)/cve.cyclonedx.json"
    print "Vulnerability scan completed"

    # Return the reports directory path
    print $reports_dir
}
