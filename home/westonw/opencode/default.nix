{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  opencode = inputs.nixpkgs-opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  opencodeVersion = builtins.head (lib.splitString "+" opencode.version);
  sleevEnabled = true;
  sleev = pkgs.stdenvNoCC.mkDerivation {
    pname = "sleev";
    version = "1.6.7";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/sleev-linux-x64/-/sleev-linux-x64-1.6.7.tgz";
      hash = "sha256-ZanhuXZpM/TNvoJzFaRM7oKvS0XE3HlkMM4BBqjTyFE=";
    };

    sourceRoot = "package";

    installPhase = ''
      runHook preInstall

      install -Dm755 bin/sleev $out/bin/sleev

      runHook postInstall
    '';
  };
  # The upstream desktop flake currently fails its Bun version check.
  opencodeDesktop = pkgs.appimageTools.wrapType2 {
    pname = "opencode-desktop";
    version = opencodeVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v${opencodeVersion}/opencode-desktop-linux-x86_64.AppImage";
      hash = "sha256-DIDIQ3xK4HoH1ibrAEiye/AOGWiHjpBTibR11ZdbpOE=";
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
  home.packages = [
    opencodeDesktopWayland
    sleev
  ];

  # OpenCode is updated through the flake input, never its curl-based self-updater.
  programs.opencode = {
    enable = true;
    package = opencode;
    settings = (
      {
        "$schema" = "https://opencode.ai/config.json";
        autoupdate = false;
        permission.external_directory = "allow";
        agent.explore = {
          model = "openai/gpt-5.6-terra";
          variant = "low";
        };
        mcp.linear_ember = {
          type = "remote";
          url = "https://mcp.linear.app/mcp";
          enabled = true;
        };
        mcp.linear_proxy = {
          type = "remote";
          url = "https://mcp.linear.app/mcp";
          enabled = true;
        };
      }
      // lib.optionalAttrs sleevEnabled {
        compaction.prune = false;
        provider.openai.options = {
          baseURL = "http://127.0.0.1:17321";
          headers = {
            sleeve-provider = "codex";
            sleeve-harness = "opencode";
          };
        };
      }
    );
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
