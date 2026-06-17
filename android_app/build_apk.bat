@echo off
setlocal enableextensions

pushd "%~dp0"
set "LOG_FILE=%CD%\build_apk.log"
set "FLUTTER_CMD=flutter"

echo ========================================
echo  Android APK build
echo  Project: %CD%
echo  Log: %LOG_FILE%
echo ========================================
echo.

(
  echo ========================================
  echo Android APK build
  echo Project: %CD%
  echo Started: %DATE% %TIME%
  echo ========================================
) > "%LOG_FILE%"

where flutter >nul 2>nul
if errorlevel 1 (
  call :find_flutter_from_local_properties
) else (
  for /f "delims=" %%F in ('where flutter') do (
    if /I "%%~xF"==".bat" (
      set "FLUTTER_CMD=%%F"
      goto found_flutter_on_path
    )
  )
  :found_flutter_on_path
  if exist "%FLUTTER_CMD%" set "FLUTTER_FOUND=1"
  if defined FLUTTER_FOUND (
    echo Using Flutter from PATH: %FLUTTER_CMD%
    echo Using Flutter from PATH: %FLUTTER_CMD% >> "%LOG_FILE%"
  )
)

if not defined FLUTTER_FOUND (
  echo Flutter was not found on PATH or android\local.properties.
  echo Please install Flutter or update flutter.sdk first.
  echo Flutter was not found on PATH or android\local.properties. >> "%LOG_FILE%"
  goto fail
)

echo Running flutter pub get...
call :run_flutter pub get
if errorlevel 1 (
  echo.
  echo flutter pub get failed.
  call :try_repair_engine_stamp
  if errorlevel 1 goto fail

  echo Retrying flutter pub get...
  call :run_flutter pub get
  if errorlevel 1 goto fail
)

echo.
echo Building release APK...
call :run_flutter build apk --release
if errorlevel 1 (
  echo.
  echo APK build failed.
  goto fail
)

echo.
echo Build complete.
echo Output: %CD%\build\app\outputs\flutter-apk\
echo Build complete. >> "%LOG_FILE%"

popd
pause
exit /b 0

:find_flutter_from_local_properties
set "FLUTTER_FOUND="
if not exist "android\local.properties" exit /b 0

for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Get-Content -LiteralPath 'android\local.properties' | Where-Object { $_ -like 'flutter.sdk=*' } | Select-Object -First 1; if ($p) { ($p.Substring(12) -replace '\\\\','\') }"`) do (
  set "FLUTTER_SDK=%%S"
)

if not defined FLUTTER_SDK exit /b 0
if exist "%FLUTTER_SDK%\bin\flutter.bat" (
  set "FLUTTER_CMD=%FLUTTER_SDK%\bin\flutter.bat"
  set "FLUTTER_FOUND=1"
  echo Using Flutter SDK from local.properties: %FLUTTER_SDK%
  echo Using Flutter SDK from local.properties: %FLUTTER_SDK% >> "%LOG_FILE%"
)
exit /b 0

:run_flutter
echo ^> "%FLUTTER_CMD%" %* >> "%LOG_FILE%"
cmd /d /c ""%FLUTTER_CMD%" %*" >> "%LOG_FILE%" 2>&1
set "LAST_ERROR=%ERRORLEVEL%"
type "%LOG_FILE%" | findstr /C:"Error: Unable to determine engine version" >nul 2>nul
if not errorlevel 1 set "ENGINE_STAMP_ERROR=1"
exit /b %LAST_ERROR%

:try_repair_engine_stamp
if not "%ENGINE_STAMP_ERROR%"=="1" exit /b 1

echo.
echo Flutter engine cache looks broken: engine.stamp already exists.
echo This script can delete only this Flutter cache stamp and retry.
choice /C YN /M "Delete Flutter engine.stamp and retry"
if errorlevel 2 exit /b 1

set "ENGINE_STAMP=%FLUTTER_SDK%\bin\cache\engine.stamp"
if not exist "%ENGINE_STAMP%" (
  for /f "delims=" %%F in ('where flutter 2^>nul') do (
    if /I "%%~xF"==".bat" (
      set "FLUTTER_BAT=%%F"
      goto got_flutter_bat
    )
  )
  :got_flutter_bat
  if defined FLUTTER_BAT (
    for %%D in ("%FLUTTER_BAT%\..\..") do set "ENGINE_STAMP=%%~fD\bin\cache\engine.stamp"
  )
)

if exist "%ENGINE_STAMP%" (
  echo Deleting "%ENGINE_STAMP%"
  echo Deleting "%ENGINE_STAMP%" >> "%LOG_FILE%"
  del /f "%ENGINE_STAMP%" >> "%LOG_FILE%" 2>&1
  exit /b %ERRORLEVEL%
)

echo engine.stamp was not found.
echo engine.stamp was not found. >> "%LOG_FILE%"
exit /b 1

:fail
echo.
echo Build failed. See log:
echo %LOG_FILE%
echo Build failed. >> "%LOG_FILE%"
popd
pause
exit /b 1
