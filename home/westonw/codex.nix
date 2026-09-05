{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  codex = inputs.nixpkgs-codex.legacyPackages.${pkgs.stdenv.hostPlatform.system}.codex;
  chatgpt = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt.override {
    commandLineArgs = "--enable-features=WaylandWindowDecorations --enable-wayland-ime=true";
  };
in
{
  # The desktop runtime discovers bwrap on PATH; upstream only wraps the CLI.
  home.packages = [
    codex
    chatgpt
    pkgs.bubblewrap
  ];
}
