@echo off
setlocal enableextensions

pushd "%~dp0"

echo ========================================
echo  Android APK build
echo  Project: %CD%
echo ========================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found on PATH.
  echo Please install Flutter or update your PATH first.
  popd
  pause
  exit /b 1
)

echo Running flutter pub get...
flutter pub get
if errorlevel 1 (
  echo.
  echo flutter pub get failed.
  popd
  pause
  exit /b 1
)

echo.
echo Building release APK...
flutter build apk --release
if errorlevel 1 (
  echo.
  echo APK build failed.
  popd
  pause
  exit /b 1
)

echo.
echo Build complete.
echo Output: %CD%\build\app\outputs\flutter-apk\

popd
pause
