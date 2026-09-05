{
  config,
  pkgs,
  lib,
  ...
}:

{
  users.users.westonw = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
}
