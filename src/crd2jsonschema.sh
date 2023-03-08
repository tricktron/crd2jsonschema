#!/usr/bin/env bash

set -euo pipefail

function cli_help() {
    echo "
crd2jsonschema converts Kubernetes Custom Resource Definitions (CRDs) to JSON schema draft 4.
Usage: crd2jsonschema [command]
Available Commands:
  convert   Convert
  version   Print the version of crd2jsonschema
  *         Help
"
  exit 1
}

function convert_to_strict_json()
{
    yq -e '.spec.versions.0.schema.openAPIV3Schema' "$1" | yq -e 'with(.. | 
        select(has("properties")) | 
        select(has("additionalProperties") | not); 
        .additionalProperties = false)' | 
        yq -e -o json -I 4
}

function convert_to_jsonschema4()
{
    cat | main.js
}

function main()
{
    case "$1" in
    "convert")
        convert_to_strict_json "$2" | convert_to_jsonschema4
        ;;
        "version")
        echo "crd2jsonschema version $(cat "$WORKDIR"/VERSION)"
        ;;
    *)
        cli_help
        ;;
esac
}

WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export WORKDIR

if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
    main "$@"
fi