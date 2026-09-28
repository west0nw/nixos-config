{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  simpleMcpEnv = import ./simple-mcp-env.nix { inherit pkgs; };
  codexUpstream = inputs.nixpkgs-codex.legacyPackages.${pkgs.stdenv.hostPlatform.system}.codex;
  codex = pkgs.symlinkJoin {
    name = "codex-with-simple-mcp";
    paths = [ codexUpstream ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/codex --run '. ${simpleMcpEnv}'
    '';
  };
  chatgptUpstream = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt.override {
    commandLineArgs = "--enable-features=WaylandWindowDecorations --enable-wayland-ime=true";
  };
  chatgpt = pkgs.symlinkJoin {
    name = "chatgpt-with-simple-mcp";
    paths = [ chatgptUpstream ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/chatgpt --run '. ${simpleMcpEnv}'
    '';
  };
in
{
  # The desktop runtime discovers bwrap on PATH; upstream only wraps the CLI.
  home.packages = [
    chatgpt
    pkgs.bubblewrap
  ];

  programs.codex = {
    enable = true;
    package = codex;
  };

  # Restore the writable app-managed config after removing the previous
  # Home Manager symlink. Fresh installs let Codex create the file itself.
  home.activation.restoreMutableCodexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    codexConfig="$HOME/.codex/config.toml"
    codexBackup="$codexConfig.backup"

    if [[ ! -e "$codexConfig" && -f "$codexBackup" ]]; then
      cp -- "$codexBackup" "$codexConfig"
      chmod 600 "$codexConfig"
    fi
  '';

  # Keep Ember's direct connection scoped to its checkout. Proxy uses the
  # hosted Linear plugin; OAuth credentials remain in Codex's mutable storage.
  home.file."coding/web/ember_lighting/.codex/config.toml".text = ''
    [mcp_servers.linear_ember]
    url = "https://mcp.linear.app/mcp"
  '';
}
