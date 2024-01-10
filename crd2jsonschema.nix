{ pkgs ? import ./nixpkgs.nix { } }:

let 
    runtimeDeps = with pkgs;
    [ 
        wget
        shellcheck
        yq-go
        nodejs
        coreutils
    ];
in
pkgs.buildNpmPackage
{
    name              = "crd2jsonschema";
    version           = "1.0.2";
    src               = ./.;
    npmDepsHash       = "sha256-lHaBVkSWr4qyHWb6rLF9iV8WW59XCxHvIGYMjrm0lIc=";
    nativeBuildInputs = with pkgs; [ makeBinaryWrapper esbuild ];
    postPatch         = 
    ''
        patchShebangs ./src/crd2jsonschema.sh
        patchShebangs ./src/oas3tojsonschema4.js
        patchShebangs ./test/*.bats
    '';
    installPhase =
    ''
        runHook preInstall
        install -Dm755 ./src/crd2jsonschema.sh $out/bin/crd2jsonschema
        install -Dm755 ./dist/oas3tojsonschema4 $out/libexec/oas3tojsonschema4
        runHook postInstall
    '';
    nativeInstallCheckInputs = with pkgs;
    [ 
        (bats.withLibraries (p: [ p.bats-support p.bats-assert p.bats-file ]))
        shellcheck
    ]
    ++ runtimeDeps;

    doInstallCheck    = true;
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
            --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}:$out/libexec"
    '';

    passthru.runtimeDeps = runtimeDeps;
}
