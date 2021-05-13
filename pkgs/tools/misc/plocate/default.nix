{ lib
, stdenv
, fetchurl
, meson
, ninja
, pkg-config
, liburing
, zstd
, config
}:

let
  dbfile = lib.attrByPath [ "locate" "dbfile" ] "/var/cache/locatedb" config;
in stdenv.mkDerivation rec {
  pname = "plocate";
  version = "1.1.7";

  src = fetchurl {
    url = "https://plocate.sesse.net/download/${pname}-${version}.tar.gz";
    sha256 = "sha256-w3zcZ4UdJdFiTKPjkgGE3w1aNpH4G50FuwJVjsQd0Nk=";
  };

  nativeBuildInputs = [ meson ninja pkg-config ];
  buildInputs = [ liburing zstd ];

  patches = [
    ./0001-Add_dbfile_option.patch
  ];

  mesonFlags = [
    "-Ddbfile=${dbfile}"
    "-Dinstall_systemd=false"
  ];

  meta = with lib; {
    description = "A much faster implementation of locate based on posting lists";
    homepage = "https://plocate.sesse.net/";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ plabadens ];
  };
}
