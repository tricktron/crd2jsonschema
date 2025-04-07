#!/usr/bin/env bash

set -euo pipefail

function cli_help()
{
    cat << EOF

Usage: crd2jsonschema [options] [crd]...

Convert Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to
JSON schema draft 4. CRDs can be specified as a file path or as a URL.

Options:
  -o path     Output directory for JSON schema files
  -a          Create all.json which references individual files
  -v          Print the version of crd2jsonschema
  -h          Print this help
  --no-strict Disables the default strict mode which reports unknown properties as errors

Examples:

# convert a single CRD file and print to stdout
crd2jsonschema your-crd.yml

# convert a single CRD from a URL and write as group/kind_version.json to
# output dir
crd2jsonschema -o output-dir https://example.com/your-crd.yml

# convert multiple CRDs, write group/kind_version.json files to output dir and
# create all.json file
crd2jsonschema -a -o ./output your-crd1.yml your-crd2.yml
crd2jsonschema -a -o ./output ./crds/*.yml
EOF
}

function get_openapi_v3_schema()
{
    local crd
    crd="$1"
    yq -e '.spec.versions[0].schema.openAPIV3Schema' "$crd" 2>/dev/null || \
        { echo "OpenAPI V3 schema not found. Is $crd a valid CRD?" >&2; exit 1; }
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

function get_crd_group()
{
    local crd
    crd="$1"
    yq -e '.spec.group' "$crd" 2>/dev/null || \
        { echo ".spec.group not found. Is $crd a valid CRD?" >&2; exit 1; }
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
        with(.. | select(has("properties")) | select(.type == "object") |
        select(has("additionalProperties") | not);
            .additionalProperties = false)
    ' 2>/dev/null
}

function convert_to_jsonschema4()
{
    cat | oas3tojsonschema4
}

function convert_crd_openapiv3_schema_to_jsonschema()
{
    local crd
    crd="$1"
    local crd_schema
    crd_schema="$(get_openapi_v3_schema "$crd")" || exit 1
    if [[ -n "${NO_STRICT-}" ]]; then
        echo "$crd_schema" | yq -e -o json -I 4 '.' | convert_to_jsonschema4
    else
        echo "$crd_schema" | convert_to_strict_json | convert_to_jsonschema4
    fi
}

function create_all_jsonschema()
{
    local all_jsonschema
    all_jsonschema="$(yq -e -o json -I 4 -n '{"oneOf": []}')"
    local crds jsonschema_filename group
    crds=("$@")
    for crd in "${crds[@]}"
    do
        jsonschema_filename=$(get_jsonschema_file_name "$crd")
        group=$(get_crd_group "$crd")
        # shellcheck disable=SC2016
        all_jsonschema="$(
            echo "$all_jsonschema" | \
            file="$group/$jsonschema_filename" yq -e -o json -I 4 '.oneOf += {"$ref": strenv(file)}'
        )"
    done
    echo "$all_jsonschema"
}


function main()
{
    local OUTPUT_DIR
    local CREATE_ALL_JSON
    local NO_STRICT

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                OUTPUT_DIR="$2"
                if [[ ! -d "${OUTPUT_DIR}" ]]; then
                    printf "\nOutput directory does not exist: %s\n" "$OUTPUT_DIR" >&2
                    exit 1
                fi
                shift 2
                ;;
            -a|--all)
                CREATE_ALL_JSON=1
                shift
                ;;
            --no-strict)
                NO_STRICT=1
                shift
                ;;
            -v|--version)
                echo "crd2jsonschema version $CRD2JSONSCHEMA_VERSION"
                exit 0
                ;;
            -h|--help)
                cli_help
                exit 0
                ;;
            --) # End of options
                shift
                break
                ;;
            -*) # Unknown option
                printf "\nOption does not exist : %s\n" "$1" >&2
                cli_help
                exit 1
                ;;
            *) # End of options
                break
                ;;
        esac
    done

    if [[ "$#" -eq 0 ]]; then
        cli_help
        exit 0
    fi

    local crds=()
    local current_crd
    local group
    for crd in "$@"
    do
        if [[ "$crd" == http* ]]; then
            temp_dir="$(mktemp -d)"
            wget -qO "$temp_dir/crd.yaml" "$crd"
            current_crd="$temp_dir/crd.yaml"
        else
            current_crd="$crd"
        fi

        if [[ -d "${OUTPUT_DIR-}" ]]; then
            json_schema_filename="$(get_jsonschema_file_name "$current_crd")"
            group="$(get_crd_group "$current_crd")"
            crds+=("$current_crd")
            mkdir -p "$OUTPUT_DIR/$group"
            convert_crd_openapiv3_schema_to_jsonschema "$current_crd" > "$OUTPUT_DIR/$group/$json_schema_filename"
        else
            convert_crd_openapiv3_schema_to_jsonschema "$current_crd"
        fi
    done

    if [[ -d "${OUTPUT_DIR-}" && -n "${CREATE_ALL_JSON-}" ]]; then
        create_all_jsonschema "${crds[@]}" > "$OUTPUT_DIR/all.json"
    fi
}

CRD2JSONSCHEMA_VERSION="1.1.1"
export CRD2JSONSCHEMA_VERSION

if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
    main "$@"
fi
