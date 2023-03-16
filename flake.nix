{
    description               = "crd2jsonschema-dev-shell";
    inputs.flake-utils.url    = "github:numtide/flake-utils";
    inputs.nixpkgs.url        = "github:NixOS/nixpkgs";
    inputs.nixpkgs-fork.url   = "github:tricktron/nixpkgs/f-kcov-41";
    inputs.ci-flake-lib       =
    {
        url                        = "github:tricktron/ci-flake-lib";
        inputs.nixpkgs.follows     = "nixpkgs";
    };

    outputs = { self, nixpkgs, flake-utils, nixpkgs-fork, ci-flake-lib }:
    flake-utils.lib.eachSystem
    [ 
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
        "x86_64-darwin"
    ]
    (system:
        let 
            pkgs        = import nixpkgs { inherit system; overlays = builtins.attrValues ci-flake-lib.overlays; };
            inherit (pkgs) ci-lib;
            pkgs-fork   = nixpkgs-fork.legacyPackages.${system};
            runtimeDeps = with pkgs;
            [ 
                yq-go 
                nodejs
                wget
                coreutils
            ];
            name        = "crd2jsonschema";
            version     = "1.0.0";
            crd2jsonschema-image = pkgs: pkgs.dockerTools.streamLayeredImage
            {
                inherit name;
                tag  = version;
                config =
                {
                    Entrypoint = [ "${self.packages.${system}.crd2jsonschema}/bin/crd2jsonschema" ];
                    Cmd        = [ "-h" ];
                };
                extraCommands = "mkdir -m 0777 tmp";
                contents = [ pkgs.dockerTools.caCertificates self.packages.${system}.crd2jsonschema ];
            };
        in
        {
            packages = 
            {
                crd2jsonschema-amd64-image = crd2jsonschema-image pkgs;
                crd2jsonschema = pkgs.buildNpmPackage
                {
                    inherit name version;
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
                    nativeInstallCheckInputs = with pkgs;
                    [ 
                        (bats.withLibraries (p: [ p.bats-support p.bats-assert p.bats-file ]))
                        shellcheck
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

                    postFixup =
                    ''
                        wrapProgram $out/bin/crd2jsonschema \
                            --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}:$out/bin"
                    '';
                };

                default = self.packages.${system}.crd2jsonschema;
            };

            apps = let 
                registryUser          = ''"$CI_REGISTRY_USER"'';
                registryPassword      = ''"$CI_REGISTRY_PASSWORD"'';
                registryBaseUrl       = ''"$CI_REGISTRY"'';
                imageUrlWithoutTag    = ''"$CI_REGISTRY_IMAGE"'';
            in 
            {
                dockerIntegrationTest = 
                {
                    type = "app"; 
                    program = "${pkgs.writeShellApplication
                    {
                        name          = "dockerIntegrationTest.sh";
                        runtimeInputs = with pkgs; [ docker ];
                        text          = 
                        ''
                            ${self.packages.${system}.crd2jsonschema-amd64-image} | docker load
                            docker run --rm ${name}:${version} \
                            https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/1f3e4021e27bc92f9881984a2348fe49aaa23727/helm/sealed-secrets/crds/bitnami.com_sealedsecrets.yaml
                        '';
                    }}/bin/dockerIntegrationTest.sh";
                };

                push-amd64-image-to-registry =
                { 
                    type = "app"; 
                    program = "${ci-lib.pushContainerToRegistry 
                    { 
                        inherit registryUser registryPassword;
                        streamLayeredImage = self.packages.${system}.crd2jsonschema-amd64-image;
                        imageUrlWithTag    = "${imageUrlWithoutTag}-amd64:${version}";
                    }}/bin/pushToRegistry.sh"; 
                };

                push-arm64-image-to-registry =
                { 
                    type = "app"; 
                    program = "${ci-lib.pushContainerToRegistry 
                    { 
                        inherit registryUser registryPassword;
                        streamLayeredImage = self.packages.${system}.crd2jsonschema-arm64-image;
                        imageUrlWithTag    = "${imageUrlWithoutTag}-arm64:${version}";
                    }}/bin/pushToRegistry.sh"; 
                };

                create-multi-arch-manifest = 
                { 
                    type = "app"; 
                    program = "${ci-lib.createMultiArchManifest 
                    {
                        inherit registryUser registryPassword imageUrlWithoutTag;
                        tag = version;
                    }}/bin/createMultiArchManifest.sh"; 
                };

                retag-image = 
                { 
                    type = "app"; 
                    program = "${ci-lib.retagImage 
                    {
                        inherit registryUser registryPassword registryBaseUrl;
                        imageUrlWithTag = "${imageUrlWithoutTag}:${version}";
                        newTag = "latest";
                    }}/bin/retagImage.sh"; 
                };
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
                [   (bats.withLibraries (p: [ p.bats-support p.bats-assert p.bats-file ])) ]
                    docker
                ] 
                ++ pkgs.lib.optionals 
                    (system == "x86_64-linux" || system == "aarch64-linux") 
                [ pkgs-fork.kcov ];
            };
        }
    );
}