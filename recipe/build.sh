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

cp "${RECIPE_DIR}/stack.yaml" stack.yaml

export PATH="${BUILD_PREFIX}/ghc-bootstrap/bin:${PATH}"
export STACK_ROOT="${SRC_DIR}/.stack-root"

# Use the GHC from ghc-bootstrap instead of letting stack download one.
STACK_OPTS=(
  --system-ghc
  --no-install-ghc
  --extra-include-dirs "${PREFIX}/include"
  --extra-lib-dirs "${PREFIX}/lib"
)

ghc --version | grep -F "${GHC_VERSION}"

if [[ "${target_platform}" == "linux-64" ]]; then
  # ghc-bootstrap's GHC runs against the sysroot's glibc. For Template Haskell
  # it dlopen()s the libraries listed in the sysroot's libc.so and libpthread.so
  # linker scripts, which name them by absolute path (/lib64/libc.so.6), so the
  # image's glibc gets loaded next to the sysroot one, which deadlocks or fails.
  # With bare names, ld still finds them in its search path (the sysroot) and
  # dlopen() reuses the already loaded libraries.
  sysroot_lib="${BUILD_PREFIX}/x86_64-conda-linux-gnu/sysroot/usr/lib64"
  sed -i -E '/^GROUP/ s#[^ ()]*/##g' "${sysroot_lib}/libc.so" "${sysroot_lib}/libpthread.so"
  if grep -q '^GROUP.*/' "${sysroot_lib}/libc.so" "${sysroot_lib}/libpthread.so"; then
    echo "ERROR: failed to rewrite the linker scripts in ${sysroot_lib}." >&2
    exit 1
  fi
fi

if [[ "${target_platform}" == "linux-aarch64" ]]; then
  # ghc-bootstrap links everything against a shim providing the glibc 2.27/2.28
  # symbols missing from a glibc 2.17 sysroot. The 2.28 sysroot used here has
  # them, and the shim is not available at runtime.
  ghc_settings="${BUILD_PREFIX}/ghc-bootstrap/lib/ghc-${GHC_VERSION}/lib/settings"
  sed -i 's/ -lghc_glibc_compat//' "${ghc_settings}"
  if grep -q -- -lghc_glibc_compat "${ghc_settings}"; then
    echo "ERROR: failed to remove -lghc_glibc_compat from ${ghc_settings}." >&2
    exit 1
  fi
fi

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
bash "${RECIPE_DIR}/collect_licenses.sh" --system-ghc --no-install-ghc
