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
        let 
            pkgs        = nixpkgs.legacyPackages.${system};
            runtimeDeps = with pkgs; 
            [ 
                bash 
                yq-go 
                nodejs 
            ]
            ++ 
            [ self.packages.${system}.openapi-schema-to-json-schema ];
        in
        {
            packages = 
            {
                default                      = pkgs.writeScriptBin "crd2jsonschema.sh" 
                ''
                    export PATH="${pkgs.lib.makeBinPath runtimeDeps}:$PATH"
                    ${builtins.readFile ./src/crd2jsonschema.sh}
                '';

                openapi-schema-to-json-schema = pkgs.buildNpmPackage rec
                {
                    version      = "3.2.0";
                    name         = "openapi-schema-to-json-schema";
                    src          = 
                    builtins.filterSource(path: type:
                        type == "regular" && 
                        (builtins.elem (baseNameOf path)
                        [ "package.json" "package-lock.json" "main.js"]))
                        ./src;
                    npmDepsHash  = "sha256-hmPm6CWk9gnBizNA/304kxSNTJUex7AgXUyFhjdxqcI=";
                    dontNpmBuild = true;
                    postInstall  = 
                    ''
                        mkdir -p $out/bin
                        chmod +x $out/lib/node_modules/${name}/main.js
                        ln -s $out/lib/node_modules/${name}/main.js $out/bin/main.js
                    '';
                };

            };

            devShells.default = pkgs.mkShell
            {
               packages = with pkgs;
               [
                   (bats.withLibraries (p: [ p.bats-support p.bats-assert p.bats-file ]))
                   shellcheck
                   yq-go
                   nodejs
               ];
            };
        }
    );
}