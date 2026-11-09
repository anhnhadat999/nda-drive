@echo off
chcp 65001 >nul
title Aino Proxy
cd /d "%~dp0"
where py >nul 2>nul && (set PY=py -3) || (set PY=python)
%PY% --version >nul 2>nul || (echo Chua cai Python. Tai tai https://www.python.org/downloads/ ^(nho tick "Add python.exe to PATH"^) roi chay lai file nay. & pause & exit /b)
%PY% -c "import PIL" 2>nul || (echo Dang cai Pillow de thu nho anh cho dien thoai... & %PY% -m pip install --user pillow)
%PY% aino_proxy.py
pause
