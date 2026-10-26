#!/usr/bin/env bash

# All Haskell dependencies are linked statically into the shellcheck binary,
# collect their licenses into ${SRC_DIR}/THIRDPARTY_LICENSES. Cabal installs
# them into the doc dir of the stack snapshot, or of ghc-bootstrap for the
# packages that come with GHC.

set -o xtrace -o pipefail -o errexit

to_unix_path() {
  if command -v cygpath > /dev/null; then
    cygpath -u "$1"
  else
    echo "$1"
  fi
}

stack_root=$(to_unix_path "${STACK_ROOT}")
ghc_root=$(to_unix_path "${BUILD_PREFIX}")/ghc-bootstrap
license_root=$(to_unix_path "${SRC_DIR}")/THIRDPARTY_LICENSES

stack_ls_dependencies() {
  stack --system-ghc --no-install-ghc --skip-msys --snapshot "${STACKAGE_SNAPSHOT}" \
    ls dependencies --filter ShellCheck "$@" | tr -d '\r'
}

stack_ls_dependencies --license
for pkg in $(stack_ls_dependencies --separator -); do
  # The runtime system has no doc dir, it is covered by GHC's own license.
  if [[ "${pkg}" == rts-* ]]; then
    doc_pkg="ghc-${GHC_VERSION}"
  else
    doc_pkg="${pkg}"
  fi
  license_dir="${license_root}/${pkg}"
  mkdir -p "${license_dir}"
  find "${stack_root}/snapshots" "${ghc_root}" -type d -path "*/doc/*" -name "${doc_pkg}" \
    -exec find {} -maxdepth 1 -type f \( -iname 'LICEN[CS]E*' -o -iname 'COPYING*' \) \; \
    | while read -r license_file; do
      cp "${license_file}" "${license_dir}/"
    done
  if [[ -z "$(ls -A "${license_dir}")" ]]; then
    echo "ERROR: no license file found for ${pkg}." >&2
    exit 1
  fi
done
