@echo off
@rem See windres.sh
bash "%~dp0windres.sh" fix-rc %* || exit /b 1
call "%BUILD_PREFIX%\ghc-bootstrap\bin\windres.bat" %*
