#!/usr/bin/env bats

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    PATH="$PROJECT_ROOT:$PATH"
}

@test "should convert crd openapi schema to json" {
    source "$PROJECT_ROOT"/src/commands/convert.sh
    run convert
    assert_output "hello"
}

@test "should print version" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh version
    VERSION="$(cat "$PROJECT_ROOT"/src/VERSION)"
    assert_output "crd2jsonschema version $VERSION"
}

@test "should print help" {
    run "$PROJECT_ROOT"/src/crd2jsonschema.sh help
    assert_output "
crd2jsonschema converts Kubernetes Custom Resource Definitions (CRDs) to JSON schemas.
Version: 0.1.0
Usage: crd2jsonschema [command]
Available Commands:
  convert   Convert
  version   Print the version of crd2jsonschema
  *         Help"
}