{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.minecraft-server = {
    enable = true;
    eula = true;
    openFirewall = true;
    declarative = true;
    # Keep the existing world on 1.21.11 when updating the system package set.
    package = pkgs.minecraftServers.vanilla-1-21;
    jvmOpts = "-Xms2G -Xmx4G";
    whitelist.FuriousFries = "7302fb12-8a35-4438-8802-2fa07447397b";
    serverProperties = {
      difficulty = "normal";
      gamemode = "survival";
      max-players = 10;
      motd = "scar - friends minecraft server";
      server-port = 25565;
      white-list = true;
      enforce-whitelist = true;
      online-mode = true;
    };
  };
}
