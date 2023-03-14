#!/usr/bin/env bash

set -euo pipefail

function cli_help()
{
    cat << EOF

Usage: crd2jsonschema [options] [crd]...

Convert Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to 
JSON schema draft 4. CRDs can be specified as a file path or as a URL.

Options:
  -o path   Output directory for JSON schema files
  -a        Create all.json with all references to schemas (intended for 
            use with yaml language server)
  -v        Print the version of crd2jsonschema
  -h        Print this help

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
    get_openapi_v3_schema "$crd" | convert_to_strict_json | convert_to_jsonschema4
}

function create_all_jsonschema()
{
    local all_jsonschema
    all_jsonschema="$(yq -e -o json -I 4 -n '{"oneOf": []}')"
    local crd_filenames
    crd_filenames=("$@")
    for crd_filename in "${crd_filenames[@]}"
    do
        # shellcheck disable=SC2016
        all_jsonschema="$(
            echo "$all_jsonschema" | \
            file="$crd_filename" yq -e -o json -I 4 '.oneOf += {"$ref": strenv(file)}'
        )"
    done
    echo "$all_jsonschema"
}


function main()
{
    local OUTPUT_DIR
    local CREATE_ALL_JSON
    while getopts :o:vha option
    do
    case "$option" in
        o)
            OUTPUT_DIR="$OPTARG"
            if [[ ! -d "${OUTPUT_DIR}" ]]; then
                printf "\nOutput directory does not exist: %s\n" "$OUTPUT_DIR" >&2
                exit 1
            fi
            ;;
        a)
            CREATE_ALL_JSON=1
            ;;
        v)
            echo "crd2jsonschema version $CRD2JSONSCHEMA_VERSION"; exit 0
            ;;
        h)
            cli_help; exit 0
            ;;
        \?)
            printf "\nOption does not exist : %s\n" "$1" >&2; cli_help; exit 1
            ;;
    esac
    done
    
    shift $((OPTIND-1))

    local crd_filenames=()
    local current_crd
    for crd in "$@"
    do  
        if [[ "$crd" == http* ]]; then
            temp_dir="$(mktemp -d)"
            wget -qO "$temp_dir/crd.yaml" "$crd"
            current_crd="$temp_dir/crd.yaml"
        else
            current_crd="$crd"
        fi

        if [[ -d "${OUTPUT_DIR-:}" ]]; then
            json_schema_filename="$(get_jsonschema_file_name "$current_crd")"
            crd_filenames+=("$json_schema_filename")
            convert_crd_openapiv3_schema_to_jsonschema "$current_crd" > "$OUTPUT_DIR/$json_schema_filename"
        else
            convert_crd_openapiv3_schema_to_jsonschema "$current_crd"
        fi
    done

    if [[ -d "${OUTPUT_DIR-:}" && -n "${CREATE_ALL_JSON-:}" ]]; then
        create_all_jsonschema "${crd_filenames[@]}" > "$OUTPUT_DIR/all.json"
    fi
}

CRD2JSONSCHEMA_VERSION="0.1.1"
export CRD2JSONSCHEMA_VERSION

if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
    main "$@"
fi