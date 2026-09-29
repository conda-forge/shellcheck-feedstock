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

set "BINARY_HOME=%PREFIX%\bin"
set "PACKAGE_HOME=%PREFIX%\share\%PKG_NAME%-%PKG_VERSION%-%PKG_BUILDNUM%"
set "STACK_ROOT=%PACKAGE_HOME%\stackroot"

mkdir "%BINARY_HOME%"  || goto :error
mkdir "%PACKAGE_HOME%" || goto :error
mkdir "%STACK_ROOT%"   || goto :error

stack --local-bin-path "%PREFIX%\bin" ^
      --stack-root "%STACK_ROOT%" ^
      setup ^
      || goto :error
stack --local-bin-path "%PREFIX%\bin" ^
      --stack-root "%STACK_ROOT%" ^
      install --ghc-options ^
        "-optl-pthread -optlo-Os" ^
      || goto :error

strip "%PREFIX%\bin\shellcheck.exe" || goto :error

rmdir /S /Q "%PACKAGE_HOME%" || goto :error
goto :EOF

:error
echo Failed with error #%errorlevel%.
exit 1
