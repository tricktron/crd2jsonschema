{ pkgs, pkgs-fork }:

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
    version           = "1.1.1";
    src               = ./.;
    npmDepsHash       = "sha256-a3aS73p6fBSQQIl3RhiAeMnGqTPaFzA2ulhBUG6TMEM=";
    nativeBuildInputs = with pkgs; [ makeBinaryWrapper esbuild ];
    postPatch         =
    ''
        patchShebangs src/crd2jsonschema.sh patchShebangs src/oas3tojsonschema4.js patchShebangs tests
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
        shellcheck
    ]
    ++ [ pkgs-fork.bashunit ]
    ++ runtimeDeps;

    doInstallCheck    = true;
    installCheckPhase = ''
        runHook preInstallCheck
        shellcheck ./src/*.sh
        shellcheck -x ./tests/**/*.sh
        export NO_INTERNET=1
        bashunit tests
        runHook postInstallCheck
    '';

    postFixup =
    ''
        wrapProgram $out/bin/crd2jsonschema \
            --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}:$out/libexec"
    '';

    passthru.runtimeDeps = runtimeDeps;
}
