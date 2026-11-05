# Pond interface (https://github.com/bflycomputer/pond-interface), packaged
# for NixOS. Mirrors the layout of Pond's Arch packages (pond-shell,
# pond-lockscreen, pond-wallpaper, pond-screenshot), with /usr paths rewritten
# to the Nix store. Must be built against the same Qt as quickshell (>= 6.12).
{
  lib,
  stdenv,
  src,
  fetchurl,
  cmake,
  ninja,
  pkg-config,
  networkmanager,
  glib,
  xkeyboard_config,
  tzdata,
  kdePackages,
  wayland,
}:

let
  # Fonts the QML asks for by name that nixpkgs does not ship.
  googleFonts = "https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl";
  onest = fetchurl {
    name = "Onest.ttf";
    url = "${googleFonts}/onest/Onest%5Bwght%5D.ttf";
    sha256 = "0ccz99nigph2wr6qgsfh4l1458pashfw5mald15shpbmnhlmqv4n";
  };
  adventPro = fetchurl {
    name = "AdventPro.ttf";
    url = "${googleFonts}/adventpro/AdventPro%5Bwdth%2Cwght%5D.ttf";
    sha256 = "0rlp5fdkb5n0xbwl8258wwrkiq66vb585cnzvavw9gc91f9b42mn";
  };
in
stdenv.mkDerivation {
  pname = "pond-interface";
  version = "unstable-${src.lastModifiedDate or "git"}";
  inherit src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];
  buildInputs = [
    kdePackages.qtbase
    kdePackages.qtdeclarative
    kdePackages.networkmanager-qt
    wayland
    networkmanager
    glib
  ];

  dontUseCmakeConfigure = true;
  dontWrapQtApps = true;

  # (In the comments below, module.nix means modules/interface.nix.)
  postPatch = ''
    # Call tools through PATH instead of /usr/bin (shebang lines are left for
    # patchShebangs), and point at our own share dir.
    find . -type f \( -name '*.qml' -o -name '*.py' -o -name '*.kdl' -o -name '*.js' -o -name '*.jsonc' \) \
      -exec sed -i \
        -e '/^#!/!s|/usr/bin/||g' \
        -e "s|/usr/share/pond-interface|$out/share/pond-interface|g" \
        -e "s|/usr/share/X11/xkb|${xkeyboard_config}/share/X11/xkb|g" \
        -e "s|/usr/share/zoneinfo|${tzdata}/share/zoneinfo|g" {} +

    # The greeter's exit wipe ends fully transparent (it is the unlock
    # animation, which reveals a desktop underneath); at login there is
    # nothing under it yet. End on the lock colour instead, which the session
    # picks up and reveals the desktop from (module.nix, login-reveal/).
    substituteInPlace lockscreen/greeter/Main.qml --replace-fail \
      '    NetworkStatus { id: network }' \
      '    Rectangle { anchors.fill: parent; color: "#1a1409" }
        NetworkStatus { id: network }'
  '';

  buildPhase = ''
    runHook preBuild
    for dir in . screenshot/native; do
      cmake -S "$dir" -B "build/$dir" -G Ninja $cmakeFlags \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
      cmake --build "build/$dir"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    share=$out/share/pond-interface
    qml=$out/lib/qt-6/qml/Pond
    mkdir -p $share $qml

    # Quickshell configs + shared config files
    cp -r shell lockscreen config $share/
    mkdir -p $share/wallpaper
    cp -r wallpaper/catalog.json wallpaper/control.py wallpaper/included $share/wallpaper/

    # QML modules
    cp -r build/Pond/System $qml/System
    cp build/libpond_system.so $qml/System/
    mkdir -p $qml/Screenshot
    cp -r screenshot/{qmldir,State.qml,Preview.qml,clipboard.py,assets} $qml/Screenshot/
    cp -r build/screenshot/native/Pond/Screenshot/Native $qml/Screenshot/Native
    cp build/screenshot/native/libpond_screenshot_drag.so $qml/Screenshot/Native/
    cp -r wallpaper/desktop $qml/Wallpaper
    cp -r wallpaper/daylight $qml/Daylight
    find $qml \( -name '*.cpp' -o -name '*.o' -o -name '*.txt' -o -name '*.qrc' -o -name '.*' \) -delete

    # Fonts
    install -Dm644 config/fastfetch/fastfetch-flowers.ttf $out/share/fonts/truetype/fastfetch-flowers.ttf
    install -Dm644 ${onest} $out/share/fonts/truetype/Onest.ttf
    install -Dm644 ${adventPro} $out/share/fonts/truetype/AdventPro.ttf

    install -Dm644 config/applications/pond-manual.desktop $out/share/applications/pond-manual.desktop
    runHook postInstall
  '';

  meta = {
    description = "Pond desktop interface: a Quickshell shell for niri";
    homepage = "https://github.com/bflycomputer/pond-interface";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
