#!/usr/bin/env bash

set -euo pipefail

function cli_help()
{
    cat << EOF

Usage: crd2jsonschema [options] [command]

Options:
  -o path   Output directory for JSON schema files

Commands:
  convert   Convert CRDs OpenAPI V3.0 schemas to JSON schema draft 4
  version   Print the version of crd2jsonschema
  *         Help
EOF
}

function get_openapi_v3_schema()
{
    local crd
    crd="$1"
    yq -e '.spec.versions[0].schema.openAPIV3Schema' "$crd" 2>/dev/null || \
        { echo "OpenAPI V3 schema not found. Is $crd a CRD?" >&2; exit 1; }
}

function get_crd_kind()
{
    local crd
    crd="$1"
    yq -e '.spec.names.singular' "$crd" 2>/dev/null || \
        { echo ".spec.names.singular not found. Is $crd a valid CRD?" >&2; exit 1; }
}

function get_crd_version()
{
    local crd
    crd="$1"
    yq -e '.spec.versions[0].name' "$crd" 2>/dev/null || \
        { echo ".spec.versions[0].name not found. Is $crd a valid CRD?" >&2; exit 1; }
}

function get_jsonschema_file_name()
{   
    local crd
    crd="$1"
    local crd_kind
    crd_kind="$(get_crd_kind "$crd")" || exit 1
    local crd_version
    crd_version="$(get_crd_version "$crd")" || exit 1
    echo "${crd_kind}_${crd_version}.json"
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
    local crd
    crd="$1"
    local openapiv3_schema
    openapiv3_schema="$(get_openapi_v3_schema "$1")" || exit 1
    local strict_schema
    strict_schema="$(echo "$openapiv3_schema" | convert_to_strict_json)" || exit 1
    echo "$strict_schema" | convert_to_jsonschema4
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
            printf "\nOption does not exist : %s\n" "$1" >&2; cli_help; exit 1
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
                    json_schema_filename="$(get_jsonschema_file_name "$crd")"
                    json_schema="$(convert_crd_openapiv3_schema_to_jsonschema "$crd")"
                    echo "$json_schema" > "$OUTPUT_DIR/$json_schema_filename"
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