@echo off
cd /d %~dp0
set API_BASE_URL=http://192.168.1.100:8000/api
echo Edit START_FLUTTER_PHONE.bat and replace API_BASE_URL with your computer LAN IP.
flutter run --dart-define=API_BASE_URL=%API_BASE_URL%
