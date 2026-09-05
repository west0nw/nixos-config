{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/base.nix
    ../../modules/common/user-westonw.nix
    ../../modules/roles/server.nix
    ../../modules/services/minecraft.nix
  ];

  networking.hostName = "scar";
  networking.networkmanager.enable = true;

  users.users.westonw.extraGroups = [
    "minecraft"
  ];

  # Don't change this ever
  system.stateVersion = "25.11";
}
