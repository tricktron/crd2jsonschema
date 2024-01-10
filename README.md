![CI](https://github.com/tricktron/crd2jsonschema/actions/workflows/main.yml/badge.svg)
[![codecov](https://codecov.io/gh/tricktron/crd2jsonschema/branch/main/graph/badge.svg?token=H2WRI0VUCQ)](https://codecov.io/gh/tricktron/crd2jsonschema)
![licence](https://img.shields.io/github/license/tricktron/crd2jsonschema?color=blue)

# crd2jsonschema

Converts Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to JSON schema draft 4.

## Usage

```console
Usage: crd2jsonschema [options] [crd]...

Convert Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to 
JSON schema draft 4. CRDs can be specified as a file path or as a URL.

Options:
  -o path   Output directory for JSON schema files
  -a        Create all.json with all references to schemas (intended for 
            use with yaml language server)
  -v        Print the version of crd2jsonschema
  -h        Print this help

Examples:

# convert a single CRD file and print to stdout
crd2jsonschema your-crd.yml

# convert a single CRD from a URL and write as kind_group_version.json to output dir 
crd2jsonschema -o output-dir https://example.com/your-crd.yml

# convert multiple CRDs, write kind_group_version.json files to output dir and
# create all.json with all references to schemas
crd2jsonschema -a -o ./output your-crd1.yml your-crd2.yml
crd2jsonschema -a -o ./output ./crds/*.yml
```

## Installation

### Docker

```bash
# convert a single CRD and write to output dir
docker run --rm -v $(pwd):/app ghcr.io/tricktron/crd2jsonschema -o output your-crd.yaml
# convert multiple CRDs, write kind_group_version.json files to output dir and
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