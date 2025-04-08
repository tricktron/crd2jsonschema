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
    local crd version_index
    version_index="${2:-0}"
    crd="$1"
    yq -e ".spec.versions[$version_index].schema.openAPIV3Schema" "$crd" 2>/dev/null || \
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
    local crd version_index
    version_index="${2:-0}"
    crd="$1"
    yq -e ".spec.versions[$version_index].name" "$crd" 2>/dev/null || \
        { echo ".spec.versions[0].name not found. Is $crd a valid CRD?" >&2; exit 1; }
}

function get_crd_versions_count()
{
    local crd
    crd="$1"
    yq -e '.spec.versions | length' "$crd" 2>/dev/null || \
        { echo "Could not determine number of versions. Is $crd a valid CRD?" >&2; exit 1; }
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
    local crd version_index
    crd="$1"
    version_index="${2:-0}"
    local crd_kind
    crd_kind="$(get_crd_kind "$crd")" || exit 1
    local crd_version
    crd_version="$(get_crd_version "$crd" "$version_index")" || exit 1
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
    local crd version_index
    crd="$1"
    version_index="${2:-0}"
    local crd_schema
    crd_schema="$(get_openapi_v3_schema "$crd" "$version_index")" || exit 1
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
    local schemes=("$@")
    for scheme in "${schemes[@]}"
    do
        # shellcheck disable=SC2016
        all_jsonschema="$(
            echo "$all_jsonschema" | \
            file="$scheme" yq -e -o json -I 4 '.oneOf += {"$ref": strenv(file)}'
        )"
    done
    echo "$all_jsonschema"
}

function process_crd()
{
    local crd output_dir
    crd="$1"
    output_dir="${2:-}"

    local versions_count
    versions_count=$(get_crd_versions_count "$crd")
    local group
    group="$(get_crd_group "$crd")"
    local refs=()

    for ((i=0; i<versions_count; i++)); do
        local json_schema_filename
        json_schema_filename="$(get_jsonschema_file_name "$crd" "$i")"

        if [[ -n "$output_dir" ]]; then
            mkdir -p "$output_dir/$group"
            local output_path="$output_dir/$group/$json_schema_filename"
            convert_crd_openapiv3_schema_to_jsonschema "$crd" "$i" > "$output_path"
            refs+=("$group/$json_schema_filename")
        else
            convert_crd_openapiv3_schema_to_jsonschema "$crd" "$i"
        fi
    done

    printf "%s\n" "${refs[@]}"
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

    local all_refs=()
        for crd in "$@"
        do
            if [[ "$crd" == http* ]]; then
                temp_dir="$(mktemp -d)"
                wget -qO "$temp_dir/crd.yaml" "$crd"
                current_crd="$temp_dir/crd.yaml"
            else
                current_crd="$crd"
            fi

            if [[ -d "${OUTPUT_DIR-}" && -n "${CREATE_ALL_JSON-}" ]]; then
                readarray -t refs < <(process_crd "$current_crd" "$OUTPUT_DIR")
                all_refs+=("${refs[@]}")
            else
                process_crd "$current_crd" "${OUTPUT_DIR-}"
            fi
        done

        if [[ -d "${OUTPUT_DIR-}" && -n "${CREATE_ALL_JSON-}" ]]; then
            create_all_jsonschema "${all_refs[@]}" > "$OUTPUT_DIR/all.json"
        fi
}

CRD2JSONSCHEMA_VERSION="1.2.0"
export CRD2JSONSCHEMA_VERSION

if [ "${BASH_SOURCE[0]}" -ef "$0" ]
then
    main "$@"
fi
