{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Hint Electron apps to use Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Display manager: greetd + tuigreet (replaces getty autologin)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # Polkit agent for GUI authentication dialogs
  security.polkit.enable = true;
  systemd.user.services.polkit-agent = {
    description = "Polkit authentication agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Power management
  services.power-profiles-daemon.enable = true;

  # Fingerprint reader (Goodix 27c6:609c is natively supported)
  services.fprintd.enable = true;

  # Allow wheel group to enroll fingerprints without authentication
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "net.reactivated.fprint.device.enroll" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Keep password-first authentication without replacing NixOS's account/session rules.
  security.pam.services.greetd.fprintAuth = true;
  security.pam.services.sudo = {
    fprintAuth = true;
    rules.auth.fprintd.order = config.security.pam.services.sudo.rules.auth.unix.order + 10;
  };
  security.pam.services.hyprlock = {
    fprintAuth = true;
    rules.auth.fprintd.order = config.security.pam.services.hyprlock.rules.auth.unix.order + 10;
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };
  services.blueman.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.space-mono
    orbitron
    noto-fonts
    noto-fonts-color-emoji
  ];

  # ── Stylix Theming ─────────────────────────────────────────────────────────────

  stylix = {
    enable = true;
    polarity = "dark";

    # Catppuccin Mocha color scheme
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    # Wallpaper (swap by changing the path to any image in ../../wallpapers/)
    image = ../../wallpapers/train-sideview.png;

    # Fonts
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.space-mono;
        name = "SpaceMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 12;
        terminal = 13;
        desktop = 11;
        popups = 12;
      };
    };

    # Cursor
    cursor = {
      package = pkgs.catppuccin-cursors.mochaLight;
      name = "catppuccin-mocha-light-cursors";
      size = 24;
    };

    # Opacity (slightly transparent for the polished look)
    opacity = {
      applications = 0.95;
      terminal = 0.9;
      desktop = 0.9;
      popups = 0.95;
    };
  };
}
