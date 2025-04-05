{
    description                    = "crd2jsonschema-dev-shell";
    inputs.flake-utils.url         = "github:numtide/flake-utils";
    inputs.nixpkgs.url             = "github:NixOS/nixpkgs/nixos-unstable";
    inputs.nixpkgs-fork.url        = "github:tricktron/nixpkgs/f-bashunit";
    inputs.ci-flake-lib       =
    {
        url                        = "github:tricktron/ci-flake-lib";
        inputs.nixpkgs.follows     = "nixpkgs";
    };
    inputs.flake-compat       =
    {
        url = "github:edolstra/flake-compat";
        flake = false;
    };

    outputs = { self, nixpkgs, nixpkgs-fork, flake-utils, ci-flake-lib, ... }:
    flake-utils.lib.eachSystem
    [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
        "x86_64-darwin"
    ]
    (system:
        let
            inherit (nixpkgs) lib;
            pkgs        = (nixpkgs.legacyPackages.${system}.extend
            (
                lib.composeManyExtensions (builtins.attrValues ci-flake-lib.overlays)
            ));
            inherit (pkgs) ci-lib;
            name                 = self.packages.${system}.crd2jsonschema.name;
            version              = self.packages.${system}.crd2jsonschema.version;
            pkgs-fork            = nixpkgs-fork.legacyPackages.${system}.pkgs;

            crd2jsonschema-image = pkgs: pkgs.dockerTools.streamLayeredImage
            {
                inherit name;
                tag            = version;
                extraCommands  =
                ''
                    mkdir -m 0755 {tmp,app}
                '';
                contents       =
                [
                    pkgs.dockerTools.caCertificates
                    self.packages.${system}.crd2jsonschema
                ];
                config         =
                {
                    Entrypoint = [ "${self.packages.${system}.crd2jsonschema}/bin/crd2jsonschema" ];
                    Cmd        = [ "-h" ];
                    WorkingDir = "/app";
                };
            };
        in
        {
            packages =
            {
                crd2jsonschema-amd64-image = crd2jsonschema-image pkgs.pkgsStatic;
                crd2jsonschema-arm64-image = crd2jsonschema-image pkgs.pkgsCross.aarch64-multiplatform-musl.pkgsStatic;
                crd2jsonschema             = pkgs.callPackage ./crd2jsonschema.nix { };

                default = self.packages.${system}.crd2jsonschema;
            };

            apps = let
                registryUser          = ''"$CI_REGISTRY_USER"'';
                registryPassword      = ''"$CI_REGISTRY_PASSWORD"'';
                registryBaseUrl       = ''"$CI_REGISTRY_BASE_URL"'';
                imageUrlWithoutTag    = ''"$CI_REGISTRY_IMAGE"'';
            in
            {
                dockerIntegrationTest =
                {
                    type    = "app";
                    program = "${pkgs.writeShellApplication
                    {
                        name          = "dockerIntegrationTest.sh";
                        runtimeInputs = with pkgs; [ docker ];
                        text          =
                        ''
                            ${self.packages.${system}.crd2jsonschema-amd64-image} | docker load
                            docker run ${name}:${version} \
                                https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/1f3e4021e27bc92f9881984a2348fe49aaa23727/helm/sealed-secrets/crds/bitnami.com_sealedsecrets.yaml
                            docker run -v "$(pwd)":/app ${name}:${version} -a -o out \
                                test/fixtures/*.crd.yml
                            cat out/route_route.openshift.io_v1.json
                            cat out/all.json
                            rm out/route_route.openshift.io_v1.json
                            rm out/all.json
                        '';
                    }}/bin/dockerIntegrationTest.sh";
                };

                push-amd64-image-to-registry =
                {
                    type    = "app";
                    program = "${ci-lib.pushContainerToRegistry
                    {
                        inherit registryUser registryPassword;
                        streamLayeredImage = self.packages.${system}.crd2jsonschema-amd64-image;
                        imageUrlWithTag    = "${imageUrlWithoutTag}-amd64:${version}";
                    }}/bin/pushToRegistry.sh";
                };

                push-arm64-image-to-registry =
                {
                    type    = "app";
                    program = "${ci-lib.pushContainerToRegistry
                    {
                        inherit registryUser registryPassword;
                        streamLayeredImage = self.packages.${system}.crd2jsonschema-arm64-image;
                        imageUrlWithTag    = "${imageUrlWithoutTag}-arm64:${version}";
                    }}/bin/pushToRegistry.sh";
                };

                create-multi-arch-manifest =
                {
                    type    = "app";
                    program = "${ci-lib.createMultiArchManifest
                    {
                        inherit registryUser registryPassword imageUrlWithoutTag;
                        tag = version;
                    }}/bin/createMultiArchManifest.sh";
                };

                retag-image =
                {
                    type    = "app";
                    program = "${ci-lib.retagImage
                    {
                        inherit registryUser registryPassword registryBaseUrl;
                        imageUrlWithTag = "${imageUrlWithoutTag}:${version}";
                        newTag = "latest";
                    }}/bin/retagImage.sh";
                };

                default =
                {
                    type    = "app";
                    program = "${self.packages.${system}.crd2jsonschema}/bin/crd2jsonschema";
                    cmdArgs = [ "-v" ];
                };
            };

            devShells.default = pkgs.mkShell
            {
               packages = with pkgs;
                [
                    esbuild
                    (bats.withLibraries (p: [ p.bats-support p.bats-assert p.bats-file ]))
                    docker
                ]
                ++ [ pkgs-fork.bashunit ]
                ++ self.packages.${system}.crd2jsonschema.passthru.runtimeDeps
                ++ pkgs.lib.optionals (system == "x86_64-linux" || system == "aarch64-linux")
                [ pkgs.kcov ];
            };
        }
    );
}
