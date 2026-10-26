@rem Refuse to cross-compile. stack has no cross-compilation support and always
@rem emits binaries for the machine it runs on, ignoring %target_platform%, so a
@rem cross build does not fail -- it silently produces a package whose binary is
@rem for the wrong architecture. This is the Windows counterpart of the check in
@rem build.sh; see conda-forge/admin-requests#2370 for how that played out on
@rem osx-arm64. There is no native stack for win-arm64, so enabling that
@rem platform would have to cross-compile from win-64 and would hit exactly this.
if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "build_platform=win-64"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "build_platform=win-arm64"
if /I "%PROCESSOR_ARCHITECTURE%"=="x86" set "build_platform=win-32"
if not defined build_platform (
  echo ERROR: unrecognized build platform %PROCESSOR_ARCHITECTURE%.
  exit 1
)
if not defined target_platform (
  echo ERROR: target_platform is not set, cannot verify the build platform.
  exit 1
)
if /I not "%build_platform%"=="%target_platform%" (
  echo ERROR: refusing to build %target_platform% on %build_platform%.
  echo        This recipe cannot be cross-compiled; build %target_platform% natively instead.
  exit 1
)

@rem rattler-build points USERPROFILE at the work directory. Cabal's Setup
@rem resolves the AppData folder through SHGetFolderPath, which expands it to
@rem %USERPROFILE%\AppData\Roaming and fails when that folder does not exist.
mkdir "%USERPROFILE%\AppData\Roaming" || goto :error

@rem GHC fails to decode localized gcc diagnostics (typographic quotes) when
@rem linking, make gcc stick to ASCII.
set "LC_ALL=C"
set "LANG=C"

set "PATH=%BUILD_PREFIX%\ghc-bootstrap\bin;%PATH%"
set "STACK_ROOT=%SRC_DIR%\.stack-root"

@rem Use the GHC from ghc-bootstrap and the conda-forge MinGW toolchain instead
@rem of letting stack download GHC and MSYS2.
set "STACK_OPTS=--system-ghc --no-install-ghc --skip-msys --resolver %STACKAGE_SNAPSHOT% --extra-include-dirs "%LIBRARY_INC%" --extra-lib-dirs "%LIBRARY_LIB%""

ghc --version | findstr /C:"%GHC_VERSION%" || goto :error

stack %STACK_OPTS% build ^
      --copy-bins --local-bin-path "%PREFIX%\bin" ^
      || goto :error

strip --strip-all "%PREFIX%\bin\shellcheck.exe" || goto :error

@rem All Haskell dependencies are linked statically into the binary, ship their
@rem licenses.
bash "%RECIPE_DIR%\collect_licenses.sh" || goto :error
goto :EOF

:error
echo Failed with error #%errorlevel%.
exit 1
