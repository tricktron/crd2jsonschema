setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$PROJECT_ROOT:$PATH"
}

@test "should convert crd openapi schema to json" {
    source src/commands/convert.sh
    run convert
    assert_output "hello"
}