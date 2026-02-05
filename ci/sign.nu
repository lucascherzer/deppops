#!/usr/bin/env nu
def main [image_name: string] {
    # Sign with private key if COSIGN_PRIVATE_KEY is set, otherwise use keyless signing
    if ($env.COSIGN_PRIVATE_KEY? | is-not-empty) {
        # Write private key to a temporary file
        let key_file = (mktemp)
        $env.COSIGN_PRIVATE_KEY | save -f $key_file

        # Sign with the private key
        cosign sign --key $key_file --yes $image_name

        # Clean up
        rm $key_file
    } else {
        # Use keyless signing (OIDC)
        cosign sign --yes $image_name
    }
}
