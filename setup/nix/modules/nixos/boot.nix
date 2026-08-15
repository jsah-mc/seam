{ enableSecureBoot, ... }:

{
  boot.loader = {
    limine = {
      enable = true;
      secureBoot = {
        enable = enableSecureBoot;
        autoGenerateKeys = enableSecureBoot;
        autoEnrollKeys.enable = enableSecureBoot;
      };
    };
    efi.canTouchEfiVariables = true;
  };
}
