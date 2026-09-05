{
  pkgs,
  spicetify-nix,
  lib,
  ...
}:

let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;
    theme = lib.mkForce spicePkgs.themes.catppuccin;
    colorScheme = lib.mkForce "mocha";

    enabledExtensions = with spicePkgs.extensions; [
      adblock
      hidePodcasts
      fullAppDisplay
      shuffle
      volumePercentage
      playlistIcons
      historyShortcut
    ];

    enabledCustomApps = with spicePkgs.apps; [
      lyricsPlus
      marketplace
    ];
  };
}
