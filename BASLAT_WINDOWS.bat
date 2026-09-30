@echo off
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter PATH icinde bulunamadi. Flutter SDK kurulumunu kontrol edin.
  pause
  exit /b 1
)
call flutter pub get
if errorlevel 1 (
  echo Paketler indirilemedi. Internet baglantinizi ve hata mesajini kontrol edin.
  pause
  exit /b 1
)
call flutter run -d chrome
pause
