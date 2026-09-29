#!/usr/bin/env bash

set -o xtrace -o pipefail -o errexit

# Refuse to cross-compile. stack has no cross-compilation support and always
# emits binaries for the machine it runs on, ignoring ${target_platform}, so a
# cross build does not fail -- it silently produces a package whose binary is
# for the wrong architecture. That is how the osx-arm64 packages up to 0.10.0
# ended up shipping x86_64 binaries and had to be marked broken, see
# conda-forge/admin-requests#2370. The linux branch below does unpack a prebuilt
# binary for ${target_platform}, but strips it with the build platform's
# binutils, so it does not survive cross-compilation either.
# conda-build does not export ${build_platform}, so derive it from uname.
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64) build_platform=linux-64 ;;
  Linux/aarch64) build_platform=linux-aarch64 ;;
  Linux/ppc64le) build_platform=linux-ppc64le ;;
  Darwin/x86_64) build_platform=osx-64 ;;
  Darwin/arm64) build_platform=osx-arm64 ;;
  *)
    echo "ERROR: unrecognized build platform $(uname -s)/$(uname -m)." >&2
    exit 1
    ;;
esac

if [[ "${build_platform}" != "${target_platform}" ]]; then
  echo "ERROR: refusing to build ${target_platform} on ${build_platform}." >&2
  echo "       This recipe cannot be cross-compiled; build ${target_platform} natively instead." >&2
  exit 1
fi

BINARY_HOME=${PREFIX}/bin
PACKAGE_HOME=${PREFIX}/share/${PKG_NAME}-${PKG_VERSION}-${PKG_BUILDNUM}
export STACK_ROOT=${PACKAGE_HOME}/stackroot
export LIBRARY_PATH=${LIBRARY_PATH}:${PREFIX}/lib # required for gmp etc. to be found

mkdir -p "${BINARY_HOME}"
mkdir -p "${PACKAGE_HOME}"
mkdir -p "${STACK_ROOT}"

STACK_OPTS="\
--local-bin-path ${PREFIX}/bin \
--extra-include-dirs ${PREFIX}/include \
--extra-lib-dirs ${PREFIX}/lib \
--stack-root ${STACK_ROOT} "

if [[ $target_platform =~ linux.* ]]; then
  install shellcheck "$PREFIX/bin/shellcheck"
  strip --strip-all "$PREFIX/bin/shellcheck"
else
  stack ${STACK_OPTS} setup
  stack ${STACK_OPTS} install --ghc-options \
    "-optlo-Os -optl-L${PREFIX}/lib -optl-Wl,-rpath,${PREFIX}/lib"
  strip "$PREFIX/bin/shellcheck"
fi

rm -rf "${PACKAGE_HOME}"
