@echo off
chcp 932 >nul
setlocal
set "DEST=%LOCALAPPDATA%\Programs\スリープ防止ツール"

echo.
echo   スリープ防止ツール  アンインストール
echo   ====================================
echo.
choice /c YN /n /t 15 /d N /m "  アンインストールしますか? (Y/N) "
if errorlevel 2 exit /b 0

rem 起動中なら終了（抑止も解除される）
taskkill /f /im "スリープ防止.exe" >nul 2>nul

rem ショートカット削除
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\スリープ防止.lnk" >nul 2>nul
del "%USERPROFILE%\Desktop\スリープ防止.lnk" >nul 2>nul
del "%USERPROFILE%\OneDrive\デスクトップ\スリープ防止.lnk" >nul 2>nul

rem 登録削除
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\SleepGuardTCloud" /f >nul 2>nul

echo.
echo   [完了] アンインストールしました。
echo.
timeout /t 2 >nul

rem 自分自身ごとフォルダを削除
start "" /b cmd /c "timeout /t 2 >nul & rd /s /q ""%DEST%"""
exit /b 0
