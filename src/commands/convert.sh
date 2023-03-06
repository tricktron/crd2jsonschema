#!/usr/bin/env bash

convert_to_json()
{
    yq -o json -P '.spec.versions[0].schema.openAPIV3Schema' "$1"
}
