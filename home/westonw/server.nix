{
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    # Editor
    inputs.nixvim.homeModules.nixvim
    ./nixvim
  ];

  home.username = "westonw";
  home.homeDirectory = "/home/westonw";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    btop
    curl
    wget
    unzip
    jq
    tmux
  ];

  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/nixos-config#scar";
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "Weston-Wallace";
      email = "weston.wallace@outlook.com";
    };
  };

  # Let home-manager manage itself
  programs.home-manager.enable = true;
}
