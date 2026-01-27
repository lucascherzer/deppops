#!/usr/bin/env nu
def main [image_name: string] {
    let reports_dir = (mktemp -d)
    syft -o spdx-json $image_name | save -f $"($reports_dir)/sbom.spdx.json"
    grype -o spdx-json $image_name | save -f $"($reports_dir)/cve.spdx.json"

    cosign attach sbom --sbom $"($reports_dir)/sbom.spdx.json" $image_name
    cosign attach sbom --sbom $"($reports_dir)/cve.spdx.json" $image_name
}
