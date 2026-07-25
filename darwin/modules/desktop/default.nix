{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs;
    [
      lens
      jetbrains.datagrip
      obsidian
      slack
      # postman
    ]
    ++ lib.optionals stdenv.isDarwin [
      ghostty-bin
    ]
    ++ lib.optionals stdenv.isLinux [
      ghostty
    ];
}
