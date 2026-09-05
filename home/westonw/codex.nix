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

  # Keep Ember's direct connection scoped to its checkout. Proxy uses the
  # hosted Linear plugin; OAuth credentials remain in Codex's mutable storage.
  home.file."coding/web/ember_lighting/.codex/config.toml".text = ''
    [mcp_servers.linear_ember]
    url = "https://mcp.linear.app/mcp"
  '';
}
