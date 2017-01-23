{ stdenv, fetchgit, bootPkgs, perl, gmp, ncurses, libiconv, binutils, coreutils
, autoconf, automake, happy, alex, python3, crossSystem, selfPkgs, cross ? null
}:

let
  inherit (bootPkgs) ghc;

  commonBuildInputs = [ ghc perl autoconf automake happy alex python3 ];

  version = "8.1.20170106";
  rev = "b4f2afe70ddbd0576b4eba3f82ba1ddc52e9b3bd";

  commonPreConfigure =  ''
    echo ${version} >VERSION
    echo ${rev} >GIT_COMMIT_ID
    ./boot
    sed -i -e 's|-isysroot /Developer/SDKs/MacOSX10.5.sdk||' configure
  '' + stdenv.lib.optionalString (!stdenv.isDarwin) ''
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath $out/lib/ghc-${version}"
  '' + stdenv.lib.optionalString stdenv.isDarwin ''
    export NIX_LDFLAGS+=" -no_dtrace_dof"
  '';
in stdenv.mkDerivation (rec {
  inherit version rev;
  name = "ghc-${version}";

  src = fetchgit {
    url = "git://git.haskell.org/ghc.git";
    inherit rev;
    sha256 = "1h064nikx5srsd7qvz19f6dxvnpfjp0b3b94xs1f4nar18hzf4j0";
  };

  postPatch = "patchShebangs .";

  preConfigure = commonPreConfigure;

  buildInputs = commonBuildInputs;

  enableParallelBuilding = true;

  configureFlags = [
    "CC=${stdenv.cc}/bin/cc"
    "--with-gmp-includes=${gmp.dev}/include" "--with-gmp-libraries=${gmp.out}/lib"
    "--with-curses-includes=${ncurses.dev}/include" "--with-curses-libraries=${ncurses.out}/lib"
  ] ++ stdenv.lib.optional stdenv.isDarwin [
    "--with-iconv-includes=${libiconv}/include" "--with-iconv-libraries=${libiconv}/lib"
  ];

  # required, because otherwise all symbols from HSffi.o are stripped, and
  # that in turn causes GHCi to abort
  stripDebugFlags = [ "-S" ] ++ stdenv.lib.optional (!stdenv.isDarwin) "--keep-file-symbols";

  checkTarget = "test";

  postInstall = ''
    paxmark m $out/lib/${name}/bin/{ghc,haddock}

    # Install the bash completion file.
    install -D -m 444 utils/completion/ghc.bash $out/share/bash-completion/completions/ghc

    # Patch scripts to include "readelf" and "cat" in $PATH.
    for i in "$out/bin/"*; do
      test ! -h $i || continue
      egrep --quiet '^#!' <(head -n 1 $i) || continue
      sed -i -e '2i export PATH="$PATH:${stdenv.lib.makeBinPath [ binutils coreutils ]}"' $i
    done
  '';

  passthru = {
    inherit bootPkgs;
  } // stdenv.lib.optionalAttrs (crossSystem != null) {
    crossCompiler = selfPkgs.ghc.override {
      cross = crossSystem;
      bootPkgs = selfPkgs;
    };
  };

  meta = {
    homepage = "http://haskell.org/ghc";
    description = "The Glasgow Haskell Compiler";
    maintainers = with stdenv.lib.maintainers; [ marcweber andres peti ];
    inherit (ghc.meta) license platforms;
  };

} // stdenv.lib.optionalAttrs (cross != null) {
  name = "${cross.config}-ghc-${version}";

  patches = [ ./ios-linker.patch ];

  preConfigure = commonPreConfigure + ''
    sed 's|#BuildFlavour  = quick-cross|BuildFlavour  = quick-cross|' mk/build.mk.sample > mk/build.mk
    echo "GhcRtsCcOpts = -glldb -Og" >> mk/build.mk
  '';

  postUnpack = ''
    mkdir -p $out/nix-support
    mv $sourceRoot $out/nix-support/source
    sourceRoot=$out/nix-support/source
  '';

  configureFlags = [
    "CC=${stdenv.ccCross}/bin/${cross.config}-cc"
    "LD=${stdenv.binutilsCross}/bin/${cross.config}-ld"
    "AR=${stdenv.binutilsCross}/bin/${cross.config}-ar"
    "NM=${stdenv.binutilsCross}/bin/${cross.config}-nm"
    "RANLIB=${stdenv.binutilsCross}/bin/${cross.config}-ranlib"
    "--target=${cross.config}"
    "--enable-bootstrap-with-devel-snapshot"
  ];

  buildInputs = commonBuildInputs ++ [ stdenv.ccCross stdenv.binutilsCross ];

  dontSetConfigureCross = true;

  dontStrip = true;

  passthru = {
    inherit bootPkgs cross;

    cc = "${stdenv.ccCross}/bin/${cross.config}-cc";

    ld = "${stdenv.binutilsCross}/bin/${cross.config}-ld";
  };
})
