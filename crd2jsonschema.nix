{ pkgs ? import ./nixpkgs.nix { } }:

let 
    runtimeDeps = with pkgs;
    [ 
        wget
        shellcheck
        yq-go
        nodejs
    ];
in
pkgs.buildNpmPackage
{
    name              = "crd2jsonschema";
    version           = "1.0.0";
    src               = ./.;
    npmDepsHash       = "sha256-gRcvPyZZ1kdR4ig1rNBwNMP5k0PkJcevZVgpFIq/wPI=";
    nativeBuildInputs = with pkgs; [ makeBinaryWrapper esbuild ];
    buildInputs = runtimeDeps;
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
        wget
        shellcheck
        yq-go
        nodejs
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

    passthru.runtimeDeps = runtimeDeps;
}