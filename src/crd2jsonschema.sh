#!/usr/bin/env bash

set -euo pipefail

function cli_help()
{
    cat << EOF

Usage: crd2jsonschema [options] [command]

Options:
  -o path  Output directory for JSON schema files

Commands:
  convert   Convert CRDs OpenAPI V3.0 schemas to JSON schema draft 4
  version   Print the version of crd2jsonschema
  *         Help
EOF
}

function get_openapi_v3_schema()
{
    yq -e '.spec.versions[0].schema.openAPIV3Schema' "$1"
}

function get_jsonschema_file_name()
{
    local CRD_KIND
    CRD_KIND="$(yq -e '.spec.names.singular' "$1")"
    local CRD_VERSION
    CRD_VERSION="$(yq -e '.spec.versions[0].name' "$1")"
    echo "${CRD_KIND}_${CRD_VERSION}.json"
}


function convert_to_strict_json()
{
    yq -e -o json -I 4 '
        with(.. | select(has("properties")) | 
        select(has("additionalProperties") | not); 
            .additionalProperties = false)
    '
}

function convert_to_jsonschema4()
{
    cat | main.js
}

function convert_crd_openapiv3_schema_to_jsonschema()
{
    get_openapi_v3_schema "$1" | \
        convert_to_strict_json | \
        convert_to_jsonschema4
}


function main()
{
    local OUTPUT_DIR
    while getopts :o: option
    do
    case "$option" in
        o)
            OUTPUT_DIR="$OPTARG"
            ;;
        \?)
            printf "\nOption does not exist : %s\n" "$1" >&2; cli_help; exit 0
            ;;
    esac
    done
    
    shift $((OPTIND-1))

    case "$1" in
        "convert")
            shift
            for crd in "$@"
            do  
                if [[ -d "${OUTPUT_DIR-:}" ]]; then
                    JSON_SCHEMA_FILE_NAME="$(get_jsonschema_file_name "$crd")"
                    convert_crd_openapiv3_schema_to_jsonschema "$crd" > "$OUTPUT_DIR/$JSON_SCHEMA_FILE_NAME"
                else
                    convert_crd_openapiv3_schema_to_jsonschema "$crd"
                fi
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