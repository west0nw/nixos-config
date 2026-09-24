{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  opencodeUpstream =
    (inputs.nixpkgs-opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode).overrideAttrs
      (_: {
        # Upstream's completion generator runs after buildPhase changes into packages/cli.
        # It fails in the sandbox because that directory has no "completion" child.
        postInstall = "";
      });
  opencodeVersion = builtins.head (lib.splitString "+" opencodeUpstream.version);
  opencode = pkgs.symlinkJoin {
    name = "opencode-${opencodeVersion}-with-watcher";
    paths = [ opencodeUpstream ];
    buildInputs = [ pkgs.makeWrapper ];
    meta = opencodeUpstream.meta;
    postBuild = ''
      for executable in opencode opencode2; do
        wrapProgram $out/bin/$executable \
          --set OPENCODE_PARCEL_WATCHER_PATH \
            ${opencodeUpstream.node_modules}/packages/cli/node_modules/@parcel/watcher-linux-x64-glibc/watcher.node \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
      done
    '';
  };
  # Use the official release binary to avoid rebuilding Electron from source.
  opencodeDesktop = pkgs.appimageTools.wrapType2 {
    pname = "opencode-desktop";
    version = opencodeVersion;
    src = pkgs.fetchurl {
      url = "https://opencode.ai/files/bin/${opencodeVersion}/opencode-desktop-linux-x86_64.AppImage";
      hash = "sha256-YeAkjjg+8SjNdJtSPIOCCu4BO4Z/BKWsuf3jtyg05X0=";
    };
  };

  opencodeDesktopWayland = pkgs.symlinkJoin {
    name = "opencode-desktop-wayland";
    paths = [ opencodeDesktop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode-desktop \
        --add-flags "--ozone-platform=wayland" \
        --add-flags "--enable-features=WaylandWindowDecorations" \
        --add-flags "--enable-wayland-ime=true"
    '';
  };

in
{
  home.packages = [ opencodeDesktopWayland ];

  # Stylix emits V1 tui.json and theme tokens; V2 has a different CLI theme format.
  stylix.targets.opencode.enable = false;
  home.sessionVariables.OPENCODE_CLI_CONFIG_CONTENT = builtins.toJSON {
    theme = {
      name = "catppuccin";
      mode = "dark";
    };
  };

  # OpenCode is updated through the flake input, never its curl-based self-updater.
  programs.opencode = {
    enable = true;
    package = opencode;
    settings = {
      "$schema" = "https://opencode.ai/config.json";
      update = "disable";
      experimental.policies = [
        {
          action = "provider.use";
          resource = "opencode";
          effect = "deny";
        }
      ];
      permissions = [
        {
          action = "external_directory";
          resource = "*";
          effect = "allow";
        }
      ];
      agents.explore.model = "openai/gpt-5.6-terra#low";
      mcp.servers.linear_ember = {
        type = "remote";
        url = "https://mcp.linear.app/mcp";
      };
      mcp.servers.linear_proxy = {
        type = "remote";
        url = "https://mcp.linear.app/mcp";
      };
      mcp.servers.simple = {
        type = "local";
        command = [
          "/etc/profiles/per-user/westonw/bin/uv"
          "run"
          "--directory"
          "/home/westonw/plugins/simple"
          "--locked"
          "python"
          "scripts/server.py"
        ];
        environment.SIMPLE_CODEX_CREDENTIALS = "/home/westonw/.config/simple-codex/credentials.json";
      };
    };
  };

  xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;
  xdg.configFile."opencode/plugins/goal.js".source = ./plugins/goal.js;

  xdg.configFile."opencode/skills/wayfinder" = {
    source = "${inputs.matt-pocock-skills}/skills/engineering/wayfinder";
    recursive = true;
  };
  xdg.configFile."opencode/skills/setup-matt-pocock-skills" = {
    source = "${inputs.matt-pocock-skills}/skills/engineering/setup-matt-pocock-skills";
    recursive = true;
  };
  xdg.configFile."opencode/skills/grilling" = {
    source = "${inputs.matt-pocock-skills}/skills/productivity/grilling";
    recursive = true;
  };
  xdg.configFile."opencode/skills/domain-modeling" = {
    source = "${inputs.matt-pocock-skills}/skills/engineering/domain-modeling";
    recursive = true;
  };
  xdg.configFile."opencode/skills/research" = {
    source = "${inputs.matt-pocock-skills}/skills/engineering/research";
    recursive = true;
  };
  xdg.configFile."opencode/skills/prototype" = {
    source = "${inputs.matt-pocock-skills}/skills/engineering/prototype";
    recursive = true;
  };

  xdg.desktopEntries."ai.opencode.desktop" = {
    name = "OpenCode";
    comment = "AI coding agent desktop client";
    exec = "opencode-desktop %U";
    icon = "${inputs.nixpkgs-opencode}/packages/desktop/icons/prod/128x128@2x.png";
    terminal = false;
    type = "Application";
    categories = [ "Development" ];
  };

}
