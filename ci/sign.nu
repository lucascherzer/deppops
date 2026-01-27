#!/usr/bin/env nu
def main [image_name: string] {
    cosign sign --yes $image_name
}
