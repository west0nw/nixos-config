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
    serverProperties = {
      difficulty = "normal";
      gamemode = "survival";
      max-players = 10;
      motd = "scar - friends minecraft server";
      server-port = 25565;
      white-list = true;
    };
  };
}
