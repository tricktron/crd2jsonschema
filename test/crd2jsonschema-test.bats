#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    PATH="$PROJECT_ROOT/src:$PATH"
}

@test "should convert Openapi V3 YAML to Openapi V3 JSON disallowing additional properties NOT defined in the schema" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh

    run convert_to_strict_json "$PROJECT_ROOT"/test/fixtures/openshift-route-crd.yml

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-strict-openapi3.json)"
}

@test "should convert Openapi V3 JSON to JSON schema draft 4" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh

    run convert_to_jsonschema4 "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-strict-openapi3.json)"

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
}

@test "should convert Openapi V3 YAML CRD to JSON schema draft 4" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh convert "$PROJECT_ROOT"/test/fixtures/openshift-route-crd.yml

    assert_output "$(cat "$PROJECT_ROOT"/test/fixtures/expected-openshift-route-jsonschema4.json)"
}

@test "should print version" {
    VERSION="$(cat "$PROJECT_ROOT"/src/VERSION)"

    run "$PROJECT_ROOT"/src/crd2jsonschema.sh version

    assert_output "crd2jsonschema version $VERSION"
}

@test "should print help" {
    . "$PROJECT_ROOT"/src/crd2jsonschema.sh

    run cli_help

    assert_output "
crd2jsonschema converts Kubernetes Custom Resource Definitions (CRDs) to JSON schema draft 4.
Usage: crd2jsonschema [command]
Available Commands:
  convert   Convert
  version   Print the version of crd2jsonschema
  *         Help"
}