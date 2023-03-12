![CI](https://github.com/tricktron/crd2jsonschema/actions/workflows/main.yml/badge.svg)
[![codecov](https://codecov.io/gh/tricktron/crd2jsonschema/branch/main/graph/badge.svg?token=H2WRI0VUCQ)](https://codecov.io/gh/tricktron/crd2jsonschema)

# crd2jsonschema

Converts Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to JSON schema draft 4.

## Usage

```console
Usage: crd2jsonschema [options] [crd]...

Convert Kubernetes Custom Resource Definitions (CRDs) OpenAPI V3.0 schemas to 
JSON schema draft 4.

Options:
  -o path   Output directory for JSON schema files
  -v        Print the version of crd2jsonschema
  -h        Print this help
```

## Credits

- [yq](https://github.com/mikefarah/yq) to parse YAML files.
- [openapi-schema-to-json-schema](https://github.com/openapi-contrib/openapi-schema-to-json-schema)
to convert OpenAPI V3.0 schemas to JSON schema draft 4.