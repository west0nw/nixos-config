{
  config,
  pkgs,
  lib,
  ...
}:

{
  networking.networkmanager = {
    enable = true;
    # Keep connection transitions available when investigating intermittent failures.
    logLevel = "INFO";
    wifi.powersave = false;
  };

  # MT7925 on Linux 7.1/7.2 can silently stall with 5 + 6 GHz MLO links.
  # A NetworkManager band restriction still negotiated both links on this laptop.
  # Hide MLO support from the supplicant so its SME uses a single-link association.
  # Keep WPA3, all frequency bands, and the current kernel's separate crash fix.
  # This is a local workaround, not an upstream driver fix. Revisit after:
  # https://bugzilla.kernel.org/show_bug.cgi?id=221884
  # https://lists.infradead.org/pipermail/linux-mediatek/2026-August/112358.html
  nixpkgs.overlays = [
    (_: prev: {
      wpa_supplicant = prev.wpa_supplicant.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/drivers/driver_nl80211_capa.c \
            --replace-fail 'capa->flags2 |= WPA_DRIVER_FLAGS2_MLO;' \
            'wpa_printf(MSG_INFO, "nl80211: MLO disabled by nullrunner MT7925 workaround");'
        '';
      });
    })
  ];

  # Link frequencies, negotiated rates, and station counters are essential diagnostics.
  environment.systemPackages = [ pkgs.iw ];
}
