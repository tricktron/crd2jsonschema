#!/usr/bin/env bash

function set_up()
{
  ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/../.."
  SCRIPT="$ROOT_DIR/src/crd2jsonschema.sh"
  PATH="$ROOT_DIR/dist:$PATH"
  # shellcheck source=src/crd2jsonschema.sh
  . "$SCRIPT"
}

function  test_should_convert_OpenAPI_V3_YAML_to_OpenAPI_V3_JSON_disallowing_additional_properties_NOT_defined_in_the_schema()
{
    local expected_openapi_v3_schema strict_openapi_v3_schema
    expected_openapi_v3_schema=$(cat "$ROOT_DIR/tests/fixtures/expected-openshift-route-strict-openapi3.json")

    strict_openapi_v3_schema=$(get_openapi_v3_schema \
        "$ROOT_DIR/tests/fixtures/openshift-route-v1.crd.yml" | \
        convert_to_strict_json)

    assert_same "$expected_openapi_v3_schema" "$strict_openapi_v3_schema"
}

function test_should_convert_OpenAPI_V3_JSON_to_JSON_schema_draft_4()
{
    local expected_json_schema json_schema
    expected_json_schema=$(cat "$ROOT_DIR/tests/fixtures/expected-openshift-route-jsonschema4.json")

    json_schema=$(convert_to_jsonschema4 < "$ROOT_DIR/tests/fixtures/expected-openshift-route-strict-openapi3.json")

    assert_same "$expected_json_schema" "$json_schema"
}

function test_should_create_kind_group_version.json_file_name_from_CRD_metadata()
{
    local filename

    filename=$(get_jsonschema_file_name "$ROOT_DIR/tests/fixtures/openshift-route-v1.crd.yml")

    assert_same "route_route.openshift.io_v1.json" "$filename"
}

function test_should_exit_if_crd_has_no_names.singular_metadata()
{
    local crd_without_kind error
    crd_without_kind="$ROOT_DIR/tests/fixtures/bitnami-sealedsecret-without-kind.yml"
    assert_exit_code "1" "$(get_crd_kind "$crd_without_kind")"

    error=$( (get_crd_kind "$crd_without_kind" 2>&1 >/dev/null) || true )

    assert_same ".spec.names.singular not found. Is $crd_without_kind a valid CRD?" "$error"
}


function test_should_exit_if_crd_has_no_version_metadata()
{
    local crd_without_version error
    crd_without_version="$ROOT_DIR/tests/fixtures/bitnami-sealedsecret-without-version.yml"
    assert_exit_code "1" "$(get_crd_version "$crd_without_version")"

    error=$( (get_crd_version "$crd_without_version" 2>&1 >/dev/null) || true )
    assert_same ".spec.versions[0].name not found. Is $crd_without_version a valid CRD?" "$error"
}

function test_should_exit_if_crd_has_no_group_metadata()
{
    local crd_without_group error
    crd_without_group="$ROOT_DIR/tests/fixtures/bitnami-sealedsecret-without-group.yml"
    assert_exit_code "1" "$(get_crd_group "$crd_without_group")"

    error=$( (get_crd_group "$crd_without_group" 2>&1 >/dev/null) || true )
    assert_same ".spec.group not found. Is $crd_without_group a valid CRD?" "$error"
}


function test_should_exit_if_crd_has_no_OpenAPI_V3_schema()
{
    local crd_without_openapi_v3_schema error
    crd_without_openapi_v3_schema="$ROOT_DIR/tests/fixtures/bitnami-sealedsecret-without-openapiv3schema.yml"
    assert_exit_code "1" "$(get_openapi_v3_schema "$crd_without_openapi_v3_schema")"

    error=$( (get_openapi_v3_schema "$crd_without_openapi_v3_schema" 2>&1 >/dev/null) || true )
    assert_same "OpenAPI V3 schema not found. Is $crd_without_openapi_v3_schema a valid CRD?" "$error"
}
