#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    PATH="$PROJECT_ROOT/src:$PATH"
    TEST_TEMP_DIR="$(temp_make --prefix 'crd2jsonschema')"
    export BATSLIB_TEMP_PRESERVE=0
    export BATSLIB_TEMP_PRESERVE_ON_FAILURE=0
}

teardown() {
    temp_del "$TEST_TEMP_DIR"
}

@test "should convert Openapi V3 YAML to Openapi V3 JSON disallowing additional properties NOT defined in the schema" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh
    export -f convert_to_strict_json get_openapi_v3_schema
    
    run bash -c "get_openapi_v3_schema \
        $PROJECT_ROOT/test/fixtures/openshift-route-v1.crd.yml | \
        convert_to_strict_json"

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-strict-openapi3.json)"
}

@test "should convert Openapi V3 JSON to JSON schema draft 4" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh
    export -f convert_to_jsonschema4

    run bash -c "cat $PROJECT_ROOT/test/fixtures/expected-openshift-route-strict-openapi3.json | convert_to_jsonschema4"

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
}

@test "should convert single Openapi V3 YAML CRD to JSON schema draft 4" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh convert "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
}

@test "should convert single Openapi V3 YAML CRD to JSON schema and write to file in given output directory" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -o "$TEST_TEMP_DIR" convert "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml

    assert_file_exist "$TEST_TEMP_DIR"/route_v1.json
    run cat "$TEST_TEMP_DIR"/route_v1.json
    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
}

@test "should convert multiple Openapi V3 YAML CRDs to JSON schema draft 4" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh convert "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml "$PROJECT_ROOT"/test/fixtures/bitnami-sealedsecrets-v1alpha1.crd.yml
    
    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json && cat "$PROJECT_ROOT"/test/fixtures/expected-bitnami-sealedsecrets-jsonschema4.json)"
}

@test "should print version" {
    VERSION="$(cat "$PROJECT_ROOT"/src/VERSION)"

    run "$PROJECT_ROOT"/src/crd2jsonschema.sh "version"

    assert_output "crd2jsonschema version $VERSION"
}

@test "should print help given unknown command" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh foo

    assert_output "
Usage: crd2jsonschema [options] [command]

Options:
  -o path  Output directory for JSON schema files

Commands:
  convert   Convert CRDs OpenAPI V3.0 schemas to JSON schema draft 4
  version   Print the version of crd2jsonschema
  *         Help"
}

@test "should print help given unknown option" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh -foo convert "$PROJECT_ROOT"/test/fixtures/openshift-route-v1.crd.yml

    assert_output "
Option does not exist : -foo

Usage: crd2jsonschema [options] [command]

Options:
  -o path  Output directory for JSON schema files

Commands:
  convert   Convert CRDs OpenAPI V3.0 schemas to JSON schema draft 4
  version   Print the version of crd2jsonschema
  *         Help"
    
}