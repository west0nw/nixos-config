{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Time & Locale
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # Keyboard
  console.keyMap = "dvorak";

  # Firmware updates
  services.fwupd.enable = true;

  # System packages shared by all hosts
  environment.systemPackages = with pkgs; [
    git
    jujutsu
    pciutils
    usbutils
  ];

  # Nix settings
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
