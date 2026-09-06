{ pkgs, config, lib, ... }:
let
  developmentHome = pkgs.runCommand "development-home" { } ''
    mkdir -p "$out/env"
  '';
in
{
  name = "aur-response-toolkit";
  # Use existing Nix caches without changing daemon trust configuration.
  cachix.enable = false;
  # This repository has no background services or process-compose configuration.
  process.manager.implementation = "overmind";
  packages = with pkgs; [
    bashInteractive coreutils findutils gawk git gnugrep gnumake gnused curl
    diffutils rustc cargo clippy rustfmt stdenv.cc xz zstd bzip2 gzip gnutar python3 ruff shellcheck cacert jq actionlint zizmor markdownlint-cli2
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.procps pkgs.iproute2 ];
  env.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  scripts.repo-check.exec = "bash scripts/check-development.sh";
  enterTest = "repo-check";

  containers.shell = {
    name = "localhost/aur-response-toolkit-dev";
    version = "latest";
    # Mount source when running; never bake checkout files or local secrets in.
    copyToRoot = [ ];
    # Prepare the image's existing home; nothing is mounted here from the host.
    layers = lib.mkAfter [{
      copyToRoot = [ developmentHome ];
      perms = [{ path = developmentHome; regex = "/env"; mode = "1777"; }];
    }];
    entrypoint = [ (pkgs.writeShellScript "development-entrypoint" ''
      export PATH="${lib.makeBinPath config.packages}:$PATH"
      exec "$@"
    '') ];
    startupCommand = "bash";
  };
}
