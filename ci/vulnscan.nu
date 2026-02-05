#!/usr/bin/env nu
def main [image_name: string] {
    let reports_dir = (mktemp -d)
    # Scan the local OCI archive, not the registry reference
    syft -o spdx-json oci-archive:result | save -f $"($reports_dir)/sbom.spdx.json"
    grype -o spdx-json oci-archive:result | save -f $"($reports_dir)/cve.spdx.json"

    # Attach to the registry image (this must run after the image is pushed)
    cosign attach sbom --sbom $"($reports_dir)/sbom.spdx.json" $image_name
    cosign attach sbom --sbom $"($reports_dir)/cve.spdx.json" $image_name
}
