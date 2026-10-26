#!/usr/bin/env bash

set -o xtrace -o pipefail -o errexit

# Refuse to cross-compile. stack has no cross-compilation support and always
# emits binaries for the machine it runs on, ignoring ${target_platform}, so a
# cross build does not fail -- it silently produces a package whose binary is
# for the wrong architecture. That is how the osx-arm64 packages up to 0.10.0
# ended up shipping x86_64 binaries and had to be marked broken, see
# conda-forge/admin-requests#2370. The linux-riscv64 branch below does unpack a
# prebuilt binary for ${target_platform}, but strips it with the build
# platform's binutils, so it does not survive cross-compilation either.
# conda-build does not export ${build_platform}, so derive it from uname.
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64) build_platform=linux-64 ;;
  Linux/aarch64) build_platform=linux-aarch64 ;;
  Linux/ppc64le) build_platform=linux-ppc64le ;;
  Linux/riscv64) build_platform=linux-riscv64 ;;
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

mkdir -p "${PREFIX}/bin"

if [[ "${target_platform}" == "linux-riscv64" ]]; then
  install shellcheck "${PREFIX}/bin/shellcheck"
  strip --strip-all "${PREFIX}/bin/shellcheck"
  exit 0
fi

export PATH="${BUILD_PREFIX}/ghc-bootstrap/bin:${PATH}"
export STACK_ROOT="${SRC_DIR}/.stack-root"

# Use the GHC from ghc-bootstrap instead of letting stack download one.
STACK_OPTS=(
  --system-ghc
  --no-install-ghc
  --snapshot "${STACKAGE_SNAPSHOT}"
  --extra-include-dirs "${PREFIX}/include"
  --extra-lib-dirs "${PREFIX}/lib"
)

ghc --version | grep -F "${GHC_VERSION}"

stack "${STACK_OPTS[@]}" build \
  --copy-bins --local-bin-path "${PREFIX}/bin" \
  --ghc-options "-optl-Wl,-rpath,${PREFIX}/lib"
if [[ "${target_platform}" == osx-* ]]; then
  # Undefined symbols that are bound lazily cannot be stripped on macOS.
  "${STRIP}" -x "${PREFIX}/bin/shellcheck"
else
  "${STRIP}" --strip-all "${PREFIX}/bin/shellcheck"
fi

# All Haskell dependencies are linked statically into the binary, ship their licenses.
bash "${RECIPE_DIR}/collect_licenses.sh"
