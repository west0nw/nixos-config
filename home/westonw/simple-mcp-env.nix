{ pkgs }:

# Sourced by app wrappers at launch; the token stays in the private credentials file.
pkgs.writeText "simple-mcp-env" ''
  if [ -z "''${SIMPLE_API_TOKEN:-}" ]; then
    simpleCredentials="''${XDG_CONFIG_HOME:-$HOME/.config}/simple-codex/credentials.json"
    if [ -f "$simpleCredentials" ]; then
      SIMPLE_API_TOKEN="$(${pkgs.jq}/bin/jq -er '.token | select(type == "string" and startswith("simple_pat_"))' "$simpleCredentials")" || exit 1
      export SIMPLE_API_TOKEN
    fi
  fi
''
