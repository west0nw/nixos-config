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
  codexHome = "${config.home.homeDirectory}/.codex";
  bundledPluginCache = "${codexHome}/plugins/cache/openai-bundled";
  chatgptResources = "${chatgpt.unwrapped}/lib/chatgpt/resources";
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
    settings = {
      model = "gpt-5.6-sol";
      model_reasoning_effort = "low";
      service_tier = "default";
      approvals_reviewer = "auto_review";

      desktop = {
        "ambient-suggestions-enabled" = true;
        conversationDetailMode = "STEPS_COMMANDS";
        followUpQueueMode = "steer";
        projectlessWorkspaceRoot = "${config.home.homeDirectory}/coding/codex";
      };

      # These paths bootstrap the plugins bundled with the desktop application.
      marketplaces = {
        openai-bundled = {
          source = "${codexHome}/.tmp/bundled-marketplaces/openai-bundled";
          source_type = "local";
        };
        openai-primary-runtime = {
          source = "${config.xdg.cacheHome}/codex-runtimes/codex-primary-runtime/plugins/openai-primary-runtime";
          source_type = "local";
        };
      };

      plugins = {
        "browser@openai-bundled".enabled = true;
        "codex-app-tools@openai-bundled".enabled = true;
        "documents@openai-primary-runtime".enabled = true;
        "pdf@openai-primary-runtime".enabled = true;
        "presentations@openai-primary-runtime".enabled = true;
        "sites@openai-bundled".enabled = false;
        "spreadsheets@openai-primary-runtime".enabled = true;
        "template-creator@openai-primary-runtime".enabled = true;
        "unified-computer-use@openai-bundled".enabled = true;
        "visualize@openai-bundled".enabled = true;
      };

      # Keep the desktop's browser/computer-use bridge synchronized with its package.
      mcp_servers.node_repl = {
        command = "${chatgptResources}/cua_node/bin/node_repl";
        args = [ ];
        startup_timeout_sec = 120;
        env = {
          BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab";
          BROWSER_USE_CODEX_APP_BUILD_FLAVOR = "prod";
          BROWSER_USE_CODEX_APP_VERSION = chatgpt.version;
          BROWSER_USE_TINYSKY_ENABLED = "1";
          CODEX_CLI_PATH = "${chatgptResources}/codex";
          CODEX_HOME = codexHome;
          NODE_REPL_INSTRUCTIONS_USE_CASE_BROWSER = "";
          NODE_REPL_INSTRUCTIONS_USE_CASE_CHROME = "";
          NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS = "1000";
          NODE_REPL_NODE_MODULE_DIRS = "${chatgptResources}/cua_node/lib/node_modules";
          NODE_REPL_NODE_PATH = "${chatgptResources}/cua_node/bin/node";
          NODE_REPL_TRUSTED_CODE_PATHS = "${codexHome}:${chatgptResources}/cua_node/lib/node_modules";
          NODE_REPL_TRUSTED_SERVICES = builtins.toJSON {
            browser = "${bundledPluginCache}/browser/${chatgpt.version}/scripts/browser-service.mjs";
          };
        };
      };

      projects = {
        "${config.home.homeDirectory}".trust_level = "trusted";
        "${config.home.homeDirectory}/coding/fantasy".trust_level = "trusted";
        "${config.home.homeDirectory}/coding/godot-projects/incremental-game".trust_level = "trusted";
        "${config.home.homeDirectory}/coding/proxy".trust_level = "trusted";
        "${config.home.homeDirectory}/coding/web/ember_lighting".trust_level = "trusted";
        "${config.home.homeDirectory}/nixos-config".trust_level = "trusted";
      };

      tui.model_availability_nux."gpt-5.6-sol" = 4;
    };
  };

  # Keep Ember's direct connection scoped to its checkout. Proxy uses the
  # hosted Linear plugin; OAuth credentials remain in Codex's mutable storage.
  home.file."coding/web/ember_lighting/.codex/config.toml".text = ''
    [mcp_servers.linear_ember]
    url = "https://mcp.linear.app/mcp"
  '';
}
