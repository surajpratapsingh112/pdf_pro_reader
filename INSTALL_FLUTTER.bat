@echo off
title Flutter Installation Helper
color 0B

echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║           Flutter Install Karo - Auto Setup          ║
echo ╚══════════════════════════════════════════════════════╝
echo.

echo Step 1: Flutter SDK download ho rahi hai...
echo (Isme 5-10 minute lag sakte hain)
echo.

:: Check if winget is available (Windows 10/11)
winget --version >nul 2>&1
if not errorlevel 1 (
    echo winget se install kar rahe hain...
    winget install Google.Flutter
    winget install Google.AndroidStudio
    echo.
    echo ✅ Flutter aur Android Studio install ho gaye!
    goto :setup
)

:: Manual download instructions
echo winget nahi mila. Manually install karein:
echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║  MANUAL INSTALLATION STEPS (5 steps only):          ║
echo ╠══════════════════════════════════════════════════════╣
echo ║                                                      ║
echo ║  STEP 1: Flutter SDK Download                        ║
echo ║  https://flutter.dev/docs/get-started/install/windows║
echo ║  "Get the Flutter SDK" click karo, ZIP download karo ║
echo ║                                                      ║
echo ║  STEP 2: Extract                                     ║
echo ║  C:\flutter\ mein extract karo                       ║
echo ║                                                      ║
echo ║  STEP 3: PATH set karo                              ║
echo ║  Windows Search > "Environment Variables"            ║
echo ║  PATH mein add: C:\flutter\bin                      ║
echo ║                                                      ║
echo ║  STEP 4: Android Studio Install                     ║
echo ║  https://developer.android.com/studio                ║
echo ║  Install karo, Android SDK download hone do          ║
echo ║                                                      ║
echo ║  STEP 5: Flutter Doctor                             ║
echo ║  Command Prompt mein: flutter doctor                  ║
echo ║  Jo issues aayein unhe fix karo                     ║
echo ║                                                      ║
echo ╚══════════════════════════════════════════════════════╝
echo.

:setup
echo.
echo Install hone ke baad yeh karein:
echo.
echo  1. Naya Command Prompt kholein
echo  2. Yahan aayein: cd /d "%~dp0"
echo  3. Chalayein: flutter pub get
echo  4. Chalayein: flutter build apk --release
echo.

:: Open relevant websites
echo Websites khol rahe hain...
start https://flutter.dev/docs/get-started/install/windows
start https://developer.android.com/studio
start https://play.google.com/console

pause
