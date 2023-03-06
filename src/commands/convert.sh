#!/usr/bin/env bash

convert()
{
    yq -o json -P '.spec.versions[0].schema.openAPIV3Schema' "$1"
}
