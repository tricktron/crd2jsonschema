#!/usr/bin/env bash

set -euo pipefail

function cli_help()
{
    cat << EOF

crd2jsonschema converts Kubernetes Custom Resource Definitions (CRDs) to JSON schema draft 4.
Usage: crd2jsonschema [command]
Available Commands:
  convert   Convert
  version   Print the version of crd2jsonschema
  *         Help
EOF
}

function convert_to_strict_json()
{
    yq -e -o json -I 4 '
        .spec.versions.0.schema.openAPIV3Schema |
        with(.. | select(has("properties")) | 
        select(has("additionalProperties") | not); 
            .additionalProperties = false)
    ' "$1"
}

function convert_to_jsonschema4()
{
    cat | main.js
}

function main()
{
    local OUTPUT_DIR=">&2"
    case "$1" in
    "convert")
        shift
        for crd in "$@"
        do 
            convert_to_strict_json "$crd" | convert_to_jsonschema4 "$OUTPUT_DIR"
        done
        ;;
        "version")
        echo "crd2jsonschema version $(cat "$WORKDIR"/VERSION)"
        ;;
    *)
        cli_help && exit 1
        ;;
esac
}

WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export WORKDIR

if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
    main "$@"
fi