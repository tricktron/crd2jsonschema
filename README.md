![CI](https://github.com/tricktron/crd2jsonschema/actions/workflows/main.yml/badge.svg)
[![codecov](https://codecov.io/gh/tricktron/crd2jsonschema/branch/main/graph/badge.svg?token=H2WRI0VUCQ)](https://codecov.io/gh/tricktron/crd2jsonschema)

# crd2jsonschema

Converts Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to JSON schema draft 4.

## Usage

https://github.com/tricktron/crd2jsonschema/blob/main/src/crd2jsonschema.sh#L9-L32

## Installation

### Docker

```bash
# convert a single CRD and write to output dir
docker run --rm -v $(pwd):/app ghcr.io/tricktron/crd2jsonschema -o output your-crd.yaml
# convert multiple CRDs, write kind_version.json files to output dir and
# create all.json with all references to schemas
docker run --rm -v $(pwd):/app ghcr.io/tricktron/crd2jsonschema -a -o output crds/*.crd.yml
```

### Nix Flakes

Install and run with:

```bash
nix profile install github:tricktron/crd2jsonschema
crd2jsonschema -h
```

or run directly with `nix run github:tricktron/crd2jsonschema -- -h`

## Use Case

Catch errors in Kubernetes manifests early by validating them against the JSON 
schema before applying them to the cluster. This shortens the feedback
loop during development and can be used in CI/CD pipelines to safeguard against
invalid manifests.

The generated JSON schemas can be used with the following tools:
- [yaml-language-server](https://github.com/redhat-developer/yaml-language-server)
by adding the `all.json` file to the `yaml.schemas` setting. See also the
[this pull request](https://github.com/redhat-developer/yaml-language-server/pull/841).
- [datree](https://github.com/datreeio/datree) by contributing schemas to their
[CRDs-catalog](https://github.com/datreeio/CRDs-catalog) or by 
[manually specifying your generated schemas](https://hub.datree.io/cli/schema-validation#crd-support).

## Credits

- [yq](https://github.com/mikefarah/yq) to parse YAML files.
- [openapi-schema-to-json-schema](https://github.com/openapi-contrib/openapi-schema-to-json-schema)
to convert OpenAPI V3.0 schemas to JSON schema draft 4.