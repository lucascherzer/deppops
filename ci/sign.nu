#!/usr/bin/env nu
def main [image_name: string] {
    # Sign with private key if COSIGN_PRIVATE_KEY is set, otherwise use keyless signing
    if ($env.COSIGN_PRIVATE_KEY? | is-not-empty) {
        # Write private key to a temporary file
        let key_file = (mktemp)
        $env.COSIGN_PRIVATE_KEY | save -f $key_file

        # Sign with the private key (this uploads the signature to the registry)
        cosign sign --key $key_file --yes --upload=true $image_name

        # Clean up
        rm $key_file
    } else {
        # Use keyless signing (OIDC, this uploads the signature to the registry)
        cosign sign --yes --upload=true $image_name
    }
}
