{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Headless defaults
  services.greetd.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;
  hardware.bluetooth.enable = lib.mkForce false;
  services.blueman.enable = lib.mkForce false;

  # Remote access
  services.openssh.enable = true;

  # Keep the machine online when the lid closes
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # Low-overhead reliability tasks
  services.fstrim.enable = true;
  services.smartd.enable = true;
}
