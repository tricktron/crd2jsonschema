#!/usr/bin/env bash

set -eo pipefail

WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export WORKDIR

function help() {
    echo "
crd2jsonschema converts Kubernetes Custom Resource Definitions (CRDs) to JSON schema draft 4.
Version: $(cat "$WORKDIR"/VERSION)
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
    yq '.spec.versions.0.schema.openAPIV3Schema' "$1" | yq 'with(.. | 
        select(has("properties")) | 
        select(has("additionalProperties") | not); 
        .additionalProperties = false)' | 
        yq -o json -P
}

function run()
{
    case "$1" in
    "convert")
        convert_to_strict_json "$2"
        ;;
    "version")
        echo "crd2jsonschema version $(cat "$WORKDIR"/VERSION)"
        ;;
    *)
        help
        ;;
esac
}

run "$@"