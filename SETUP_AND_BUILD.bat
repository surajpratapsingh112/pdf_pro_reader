@echo off
title PDF Pro Reader - Flutter Setup & Build
color 0A

echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║      PDF Pro Reader - Flutter App Build Setup        ║
echo ╚══════════════════════════════════════════════════════╝
echo.

cd /d "%~dp0"

:menu
echo Kya karna chahte hain?
echo.
echo  [1] Flutter install check karo
echo  [2] Dependencies install karo (pub get)
echo  [3] Android APK build karo (release)
echo  [4] Windows EXE build karo
echo  [5] Android par test karo (USB connected hona chahiye)
echo  [6] Sab kuch ek saath karo (2+3+4)
echo  [0] Exit
echo.
set /p choice="Apna choice enter karo: "

if "%choice%"=="1" goto check_flutter
if "%choice%"=="2" goto pub_get
if "%choice%"=="3" goto build_android
if "%choice%"=="4" goto build_windows
if "%choice%"=="5" goto run_device
if "%choice%"=="6" goto do_all
if "%choice%"=="0" exit

goto menu

:check_flutter
echo.
flutter --version
if errorlevel 1 (
    echo.
    echo ❌ Flutter install nahi hai!
    echo.
    echo Flutter install karne ke liye:
    echo  1. https://flutter.dev/docs/get-started/install/windows kholein
    echo  2. Flutter SDK download karein
    echo  3. PATH mein add karein
    echo  4. Fir yeh script dobara chalayein
    echo.
    echo Ya seedha command chalayein:
    echo  winget install Google.Flutter
    echo.
) else (
    echo.
    echo ✅ Flutter sahi se install hai!
    flutter doctor
)
pause
goto menu

:pub_get
echo.
echo Dependencies install ho rahi hain...
flutter pub get
if errorlevel 1 (
    echo ❌ Error! Flutter install hai?
) else (
    echo ✅ Dependencies install ho gayi!
)
pause
goto menu

:build_android
echo.
echo ══════════════════════════════════════
echo Android APK build ho rahi hai...
echo (5-10 minute lag sakte hain)
echo ══════════════════════════════════════
flutter build apk --release
if errorlevel 1 (
    echo.
    echo ❌ Build fail! Android SDK install hai?
    echo.
    echo Install karne ke liye:
    echo  1. Android Studio install karo
    echo  2. flutter doctor chalao
    echo  3. Issues fix karo, phir dobara try karo
) else (
    echo.
    echo ✅ APK ban gayi!
    echo.
    echo APK location:
    echo  build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo Ise apne mobile par copy karo aur install karo!
    echo (Settings > Security > Unknown Sources ON karo)
    echo.
    explorer build\app\outputs\flutter-apk\
)
pause
goto menu

:build_windows
echo.
echo ══════════════════════════════════════
echo Windows EXE build ho rahi hai...
echo ══════════════════════════════════════
flutter build windows --release
if errorlevel 1 (
    echo ❌ Windows build fail!
) else (
    echo.
    echo ✅ Windows app ban gaya!
    echo.
    echo Location:
    echo  build\windows\x64\runner\Release\
    echo.
    explorer build\windows\x64\runner\Release\
)
pause
goto menu

:run_device
echo.
echo Connected devices:
flutter devices
echo.
echo Mobile par run karo:
flutter run --release
pause
goto menu

:do_all
call :pub_get
call :build_android
call :build_windows
goto menu
