{
    description               = "crd2jsonschema-dev-shell";
    inputs.flake-utils.url    = "github:numtide/flake-utils";
    inputs.nixpkgs.url        = "github:NixOS/nixpkgs";

    outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem
    [ 
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
        "x86_64-darwin"
    ]
    (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in
        {
            devShells.default     = pkgs.mkShell
            {
               packages = with pkgs;
               [
                   (bats.withLibraries (p: [ p.bats-support p.bats-assert p.bats-file ]))
                   shellcheck
                   yq-go
               ];
            };
        }
    );
}