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
  users.users.westonw.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL5AKaAB/R/8KcJ6xgySHER5SjhXxAs6kQKvHFWTsLcA weston.wallace@outlook.com"
  ];

  # Don't change this ever
  system.stateVersion = "25.11";
}
