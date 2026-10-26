#!/usr/bin/env bash

# GHC writes the path of the manifest it embeds into executables unescaped into
# a .rc file, which GNU windres parses as a C string. The paths stack builds in
# contain `\x86_64-windows`, which windres reads as a hex escape. Route GHC's
# windres calls through windres.bat, which turns those backslashes into forward
# slashes before calling ghc-bootstrap's windres wrapper.

set -o errexit

case "$1" in
  install)
    sed -i "s#\$topdir/../bin/windres.bat#$(cygpath -m "${RECIPE_DIR}")/windres.bat#" \
      "$(cygpath -u "${BUILD_PREFIX}")/ghc-bootstrap/lib/settings"
    grep -F "windres command" "$(cygpath -u "${BUILD_PREFIX}")/ghc-bootstrap/lib/settings"
    ;;
  fix-rc)
    shift
    for arg in "$@"; do
      case "${arg}" in
        --input=*) sed -i 's#\\#/#g' "$(cygpath -u "${arg#--input=}")" ;;
      esac
    done
    ;;
esac
