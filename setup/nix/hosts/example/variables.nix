{
  hostname = "example";
  system = "x86_64-linux";
  user = "joseph";
  seamRoot = "/home/joseph/seam";
  enableNvidia = false;
  enableSecureBoot = false;
  hardwareConfiguration = ./hardware-configuration.nix;
}
