{
    description               = "crd2jsonschema-dev-shell";
    inputs.flake-utils.url    = "github:numtide/flake-utils";
    inputs.nixpkgs.url        = "github:NixOS/nixpkgs";
    inputs.nixpkgs-fork.url   = "github:tricktron/nixpkgs/f-kcov-41";
    inputs.nixpkgs-bats.url   = "github:tricktron/nixpkgs/f-bats-1.9.0";

    outputs = { self, nixpkgs, flake-utils, nixpkgs-fork, nixpkgs-bats }:
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
            pkgs-fork   = nixpkgs-fork.legacyPackages.${system};
            pkgs-bats   = nixpkgs-bats.legacyPackages.${system};
            runtimeDeps = with pkgs; 
            [ 
                yq-go 
                nodejs
                wget
            ];
        in
        {
            packages = 
            {
                crd2jsonschema = pkgs.buildNpmPackage
                {
                    name              = "crd2jsonschema";
                    src               = ./.;
                    npmDepsHash       = "sha256-gRcvPyZZ1kdR4ig1rNBwNMP5k0PkJcevZVgpFIq/wPI=";
                    nativeBuildInputs = with pkgs; [ makeBinaryWrapper esbuild ];
                    postPatch         = 
                    ''
                        patchShebangs ./src/crd2jsonschema.sh
                        patchShebangs ./src/oas3tojsonschema4.js
                        patchShebangs ./test/*.bats
                    '';
                    installPhase      =
                    ''
                        runHook preInstall
                        install -Dm755 ./src/crd2jsonschema.sh $out/bin/crd2jsonschema
                        install -Dm755 ./dist/oas3tojsonschema4 $out/bin/oas3tojsonschema4
                        runHook postInstall
                    '';
                    nativeInstallCheckInputs = 
                    [ 
                        (pkgs-bats.bats.withLibraries (p: [ p.bats-support p.bats-assert p.bats-file ]))
                        pkgs.shellcheck
                    ] 
                    ++ runtimeDeps;

                    doInstallCheck = true;
                    installCheckPhase = ''
                        runHook preInstallCheck
                        shellcheck ./src/*.sh
                        shellcheck -x ./test/*.bats
                        bats --filter-tags \!internet ./test
                        runHook postInstallCheck
                    '';
                };

                default = self.packages.${system}.crd2jsonschema;
            };

            devShells.default = pkgs.mkShell
            {
               packages = with pkgs;
                [
                    wget
                    shellcheck
                    yq-go
                    nodejs
                    esbuild
                [   (pkgs-bats.bats.withLibraries (p: [ p.bats-support p.bats-assert p.bats-file ])) ]
                ] 
                ++ pkgs.lib.optionals 
                    (system == "x86_64-linux" || system == "aarch64-linux") 
                [ pkgs-fork.kcov ];
            };
        }
    );
}