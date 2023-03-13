#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    PATH="$PROJECT_ROOT/src:$PATH"
    TEST_TEMP_DIR="$(temp_make)"
    export BATSLIB_TEMP_PRESERVE=0
    export BATSLIB_TEMP_PRESERVE_ON_FAILURE=0
}

teardown() {
    temp_del "$TEST_TEMP_DIR"
}

@test "should convert OpenAPI V3 YAML to OpenAPI V3 JSON disallowing additional properties NOT defined in the schema" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh
    export -f convert_to_strict_json get_openapi_v3_schema
    
    run bash -c "get_openapi_v3_schema \
        $PROJECT_ROOT/test/fixtures/openshift-route-v1.crd.yml | \
        convert_to_strict_json"

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-strict-openapi3.json)"
}

@test "should convert OpenAPI V3 JSON to JSON schema draft 4" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh
    export -f convert_to_jsonschema4

    run bash -c "cat $PROJECT_ROOT/test/fixtures/expected-openshift-route-strict-openapi3.json | \
        convert_to_jsonschema4"

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
}

@test "should convert single OpenAPI V3 YAML CRD to JSON schema draft 4" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh \
        "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
}

@test "should convert single OpenAPI V3 YAML CRD to JSON schema and write to file in given output directory" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -o "$TEST_TEMP_DIR" \
        "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml

    assert_file_exist "$TEST_TEMP_DIR"/route_v1.json
    run cat "$TEST_TEMP_DIR"/route_v1.json
    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
}

@test "should create kind_version.json file name from CRD metadata" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh

    run get_jsonschema_file_name \
        "$PROJECT_ROOT/test/fixtures/openshift-route-v1.crd.yml"

    assert_output "route_v1.json"
}

@test "should exit if crd has no names.singular metadata" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh
    crd_without_kind="$PROJECT_ROOT/test/fixtures/bitnami-sealedsecret-without-kind.yml"

    run get_crd_kind "$crd_without_kind"
    assert_failure
    assert_output "null
.spec.names.singular not found. Is $crd_without_kind a valid CRD?"
}

@test "should exit if crd has no version metadata" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh
    crd_without_version="$PROJECT_ROOT/test/fixtures/bitnami-sealedsecret-without-version.yml"

    run get_crd_version "$crd_without_version"
    assert_failure
    assert_output "null
.spec.versions[0].name not found. Is $crd_without_version a valid CRD?"
}

@test "should exit if crd has no OpenAPI V3 schema" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh
    crd_without_openapi_v3_schema="$PROJECT_ROOT/test/fixtures/bitnami-sealedsecret-without-openapiv3schema.yml"

    run get_openapi_v3_schema "$crd_without_openapi_v3_schema"
    assert_failure
    assert_output "null
OpenAPI V3 schema not found. Is $crd_without_openapi_v3_schema a CRD?"
}

@test "should exit if output directory does not exist" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -o "$TEST_TEMP_DIR"/non-existing-dir \
        "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml

    assert_failure
    assert_output "
Output directory does not exist: $TEST_TEMP_DIR/non-existing-dir"
}

@test "should convert multiple OpenAPI V3 YAML CRDs to JSON schema and write to files in given output directory" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -o "$TEST_TEMP_DIR" \
        "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml \
        "$PROJECT_ROOT"/test/fixtures/bitnami-sealedsecret-v1alpha1.crd.yml

    assert_file_exist "$TEST_TEMP_DIR"/route_v1.json
    assert_file_exist "$TEST_TEMP_DIR"/sealedsecret_v1alpha1.json
    
    run cat "$TEST_TEMP_DIR"/route_v1.json
    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
    run cat "$TEST_TEMP_DIR"/sealedsecret_v1alpha1.json
    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-bitnami-sealedsecret-jsonschema4.json)"
}

@test "should convert multiple OpenAPI V3 YAML CRDs to JSON schema draft 4" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh \
        "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml \
        "$PROJECT_ROOT"/test/fixtures/bitnami-sealedsecret-v1alpha1.crd.yml
    
    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json \
        && cat "$PROJECT_ROOT"/test/fixtures/expected-bitnami-sealedsecret-jsonschema4.json)"
}

@test "should print help given -h option" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -h

    assert_output "
Usage: crd2jsonschema [options] [crd]...

Convert Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to 
JSON schema draft 4.

Options:
  -o path   Output directory for JSON schema files
  -v        Print the version of crd2jsonschema
  -h        Print this help"
}

@test "should print version given -v option" {
    VERSION="$(cat "$PROJECT_ROOT"/src/VERSION)"

    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -v

    assert_output "crd2jsonschema version $VERSION"
}

@test "should print help given unknown option" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -foo convert \
        "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml

    assert_failure
    assert_output "
Option does not exist : -foo

Usage: crd2jsonschema [options] [crd]...

Convert Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to 
JSON schema draft 4.

Options:
  -o path   Output directory for JSON schema files
  -v        Print the version of crd2jsonschema
  -h        Print this help"
}


@test "should create all.json with single reference given -a option" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -o "$TEST_TEMP_DIR" -a \
        "$PROJECT_ROOT"/test/fixtures/bitnami-sealedsecret-v1alpha1.crd.yml

    assert_file_exist "$TEST_TEMP_DIR"/all.json
    
    run cat "$TEST_TEMP_DIR"/all.json
    # shellcheck disable=SC2016
    assert_output "$(yq -o json -I 4 -n '{"oneOf": [{"$ref": "sealedsecret_v1alpha1.json"}]}')"
}

@test "should create all.json with multiple references given -a option" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -o "$TEST_TEMP_DIR" -a \
        "$PROJECT_ROOT"/test/fixtures/bitnami-sealedsecret-v1alpha1.crd.yml \
        "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml

    assert_file_exist "$TEST_TEMP_DIR"/all.json
    
    run cat "$TEST_TEMP_DIR"/all.json
    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-multiple-all.json)"
}