#!/usr/bin/env bash

function set_up_before_script()
{
    ROOT_DIR="$(dirname "${BASH_SOURCE[0]}")/../.."
    SCRIPT="$ROOT_DIR/src/crd2jsonschema.sh"
    PATH="$ROOT_DIR/dist:$PATH"
}

function set_up()
{
    TEMP_DIR=$(temp_dir)
}

function tear_down()
{
    rm -rf "$TEMP_DIR"
}

function test_should_print_version_given_-v_option()
{
    # shellcheck source=src/crd2jsonschema.sh
    . "$SCRIPT"
    local version

    version="$($SCRIPT -v)"

    assert_same "crd2jsonschema version $CRD2JSONSCHEMA_VERSION" "$version"
}

function test_should_print_help_given_-h_option()
{
    local help

    help="$($SCRIPT -h)"

    assert_contains "Usage: crd2jsonschema [options] [crd]..." "$help"
}

function test_should_print_help_and_fail_given_unknown_option()
{
    assert_exit_code "1" "$($SCRIPT -foo -h)"
    local help error

    error="$($SCRIPT -foo -h 2>&1 >/dev/null || true)"
    help="$($SCRIPT -foo -h 2>&1 || true)"

    assert_equals "Option does not exist : -foo" "$error"
    assert_contains "Usage: crd2jsonschema [options] [crd]..." "$help"
}

function test_should_print_help_given_no_crd() {
    local help
    help="$($SCRIPT 2>&1 || true)"

    assert_contains "Usage: crd2jsonschema [options] [crd]..." "$help"
}

function test_should_convert_single_OpenAPI_V3_YAML_CRD_file_to_JSON_schema_draft_4()
{
    local expected_json_schema json_schema
    expected_json_schema=$(cat "$ROOT_DIR/tests/fixtures/expected-openshift-route-jsonschema4.json")

    json_schema=$($SCRIPT "$ROOT_DIR/tests/fixtures/openshift-route-v1.crd.yml")

    assert_same "$expected_json_schema" "$json_schema"
}

function test_should_convert_single_OpenAPI_V3_YAML_CRD_to_JSON_schema_and_write_to_file_in_given_output_directory()
{
    $SCRIPT -o "$TEMP_DIR" "$ROOT_DIR/tests/fixtures/openshift-route-v1.crd.yml"

    assert_file_exists "$TEMP_DIR/route.openshift.io/route_v1.json"
    assert_files_equals "$ROOT_DIR/tests/fixtures/expected-openshift-route-jsonschema4.json" \
        "$TEMP_DIR/route.openshift.io/route_v1.json"
}

function test_should_exit_if_output_directory_does_not_exist()
{
    assert_exit_code "1" "$($SCRIPT -o "$TEMP_DIR/non-existing")"
    local error

    error="$($SCRIPT -o "$TEMP_DIR/non-existing" "$ROOT_DIR/tests/fixtures/openshift-route-v1.crd.yml" 2>&1 || true)"

    assert_equals "Output directory does not exist: $TEMP_DIR/non-existing" "$error"
}

function test_should_download_and_convert_single_OpenAPI_V3_YAML_CRD_http_file_to_JSON_schema_draft_4()
{
    if [[ -n $NO_INTERNET ]]; then
        skip && return
    fi

    local expected_json_schema json_schema
    expected_json_schema=$(cat "$ROOT_DIR/tests/fixtures/expected-bitnami-sealedsecret-jsonschema4.json")

    json_schema=$($SCRIPT "https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/1f3e4021e27bc92f9881984a2348fe49aaa23727/helm/sealed-secrets/crds/bitnami.com_sealedsecrets.yaml")

    assert_same "$expected_json_schema" "$json_schema"
}

function test_should_convert_multiple_OpenAPI_V3_YAML_CRDs_to_JSON_schema_draft_4()
{
    local expected_json_schemas json_schemas
    expected_json_schemas=$(cat "$ROOT_DIR/tests/fixtures/expected-openshift-route-jsonschema4.json" \
        "$ROOT_DIR/tests/fixtures/expected-bitnami-sealedsecret-jsonschema4.json")

    json_schemas=$($SCRIPT "$ROOT_DIR/tests/fixtures/openshift-route-v1.crd.yml" \
        "$ROOT_DIR/tests/fixtures/bitnami-sealedsecret-v1alpha1.crd.yml")

    assert_same "$expected_json_schemas" "$json_schemas"
}

function test_should_convert_multiple_OpenAPI_V3_YAML_CRDs_to_JSON_schema_and_write_to_files_in_given_output_directory()
{
    $SCRIPT -o "$TEMP_DIR" "$ROOT_DIR/tests/fixtures/openshift-route-v1.crd.yml" \
        "$ROOT_DIR/tests/fixtures/bitnami-sealedsecret-v1alpha1.crd.yml"
    assert_file_exists "$TEMP_DIR/route.openshift.io/route_v1.json"
    assert_file_exists "$TEMP_DIR/bitnami.com/sealedsecret_v1alpha1.json"
    assert_files_equals "$ROOT_DIR/tests/fixtures/expected-openshift-route-jsonschema4.json" \
        "$TEMP_DIR/route.openshift.io/route_v1.json"
    assert_files_equals "$ROOT_DIR/tests/fixtures/expected-bitnami-sealedsecret-jsonschema4.json" \
        "$TEMP_DIR/bitnami.com/sealedsecret_v1alpha1.json"
}

function test_should_convert_multiple_OpenAPI_V3_YAML_CRDs_to_JSON_schema_and_write_to_files_in_given_output_directory_with_same_group()
{
    $SCRIPT -o "$TEMP_DIR" "$ROOT_DIR/tests/fixtures/openshift-ingresscontroller-v1.crd.yml" \
        "$ROOT_DIR/tests/fixtures/openshift-network-v1.crd.yml"
    assert_file_exists "$TEMP_DIR/operator.openshift.io/ingresscontroller_v1.json"
    assert_file_exists "$TEMP_DIR/operator.openshift.io/network_v1.json"
}

function test_should_create_all.json_with_single_reference_given_-a_option()
{
    local expected_all_json
    # shellcheck disable=SC2016
    expected_all_json="$(yq -o json -I 4 -n '{"oneOf": [{"$ref": "bitnami.com/sealedsecret_v1alpha1.json"}]}')"

    $SCRIPT -o "$TEMP_DIR" -a "$ROOT_DIR/tests/fixtures/bitnami-sealedsecret-v1alpha1.crd.yml"

    assert_file_exists "$TEMP_DIR"/all.json
    assert_equals "$expected_all_json" "$(cat "$TEMP_DIR"/all.json)"
}

function test_should_create_all.json_with_multiple_references_given_-a_option()
{
    $SCRIPT -o "$TEMP_DIR" -a "$ROOT_DIR/tests/fixtures/bitnami-sealedsecret-v1alpha1.crd.yml" \
        "$ROOT_DIR"/tests/fixtures/openshift-route-v1.crd.yml

    assert_file_exists "$TEMP_DIR"/route.openshift.io/route_v1.json
    assert_file_exists "$TEMP_DIR"/bitnami.com/sealedsecret_v1alpha1.json
    assert_file_exists "$TEMP_DIR"/all.json
    assert_files_equals "$ROOT_DIR/tests/fixtures/expected-multiple-all.json" "$TEMP_DIR/all.json"
}

function test_should_convert_long_OpenAPI_V3_YAML_CRD_with_newlines_and_dollar_signs_to_JSON_schema_draft_4_and_write_to_file()
{
    $SCRIPT -o "$TEMP_DIR" "$ROOT_DIR/tests/fixtures/openshift-ingresscontroller-v1.crd.yml"

    assert_file_exists "$TEMP_DIR/operator.openshift.io/ingresscontroller_v1.json"
    assert_file_not_exists "$TEMP_DIR/all.json"
    assert_files_equals "$ROOT_DIR/tests/fixtures/expected-openshift-ingresscontroller-v1-jsonschema4.json" \
        "$TEMP_DIR/operator.openshift.io/ingresscontroller_v1.json"
}

