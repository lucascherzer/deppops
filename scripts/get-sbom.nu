#!/usr/bin/env nu
def main [
    --image(-i): string, # The name of the oci artifact containing the image (example: ghcr.io/lucascherzer/deppops/deppops:sha256-1f0799e6f9705324be6c2fc94ced25c983a162289849cee1702fc01b5530bb8b.sbom)
    --out(-o): path = . # The directory in which to save
]: nothing -> nothing {
    let tmp_dir = mktemp -d
    try {
        skopeo --insecure-policy copy $"docker://($image)" $"dir:($tmp_dir)"
        let sbom_file = open $"($tmp_dir)/manifest.json"
        | get layers
        | where mediaType == "text/spdx+json"
        | get digest.0
        | parse 'sha256:{hash}'
        | get hash.0
        cp $"($tmp_dir)/($sbom_file)" $"($out)/sbom.spdx.json"
    } catch { |e|
        printf $"Failed with error:\n($e)"
    }
    rm -rf $tmp_dir
}
