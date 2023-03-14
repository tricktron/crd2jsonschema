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
                    version           = "0.1.1";
                    npmDepsHash       = "sha256-jLtyUBCIgnLxwbtnayGupj6TVRwyuu7ASpdB6kAwFHA=";
                    nativeBuildInputs = with pkgs; [ makeWrapper esbuild ];
                    installPhase      =
                    ''
                        runHook preInstall
                        mkdir -p $out/bin
                        cp ./src/crd2jsonschema.sh $out/bin/crd2jsonschema
                        cp ./dist/oas3tojsonschema4.js $out/bin
                        chmod +x $out/bin/oas3tojsonschema4.js
                        chmod +x $out/bin/crd2jsonschema
                        wrapProgram $out/bin/crd2jsonschema \
                            --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}:$out/bin"
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