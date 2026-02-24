#!/usr/bin/env nu
def main [image_name: string] {
    # Sign with private key if COSIGN_PRIVATE_KEY is set, otherwise use keyless signing
    if ($env.COSIGN_PRIVATE_KEY? | is-not-empty) {
        print "Signing with private key..."
        # Write private key to a temporary file
        # usage of `str trim` ensures no newline characters are in the path
        let key_file = (mktemp | str trim)
        $env.COSIGN_PRIVATE_KEY | save -f $key_file

        # Sign with the private key
        # --tlog-upload=false is often used with private keys to avoid publishing to the public transparency log (optional)
        try {
            cosign sign --key $key_file --yes --upload=true $image_name
        } catch {
            print "Signing failed."
            rm $key_file
            exit 1
        }

        # Clean up
        rm $key_file
        print "Successfully signed with private key."
    } else {
        print "Signing with keyless (OIDC)..."
        # Use keyless signing (OIDC, this uploads the signature to the registry)
        cosign sign --yes --upload=true $image_name
        print "Successfully signed with keyless."
    }
}
