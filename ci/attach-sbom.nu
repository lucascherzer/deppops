#!/usr/bin/env nu
# Attach SBOM and vulnerability reports to a pushed container image
def main [reports_dir: string, image_name: string] {
    print $"Attaching reports from ($reports_dir) to ($image_name)"

    # Attach SBOM
    print "Attaching SBOM..."
    cosign attach sbom --sbom $"($reports_dir)/sbom.spdx.json" $image_name

    # Attach vulnerability report
    print "Attaching vulnerability report..."
    cosign attach sbom --sbom $"($reports_dir)/cve.cyclonedx.json" $image_name

    print "All reports attached successfully"
}
