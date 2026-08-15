@echo off
chcp 932 >nul
setlocal
set "DEST=%LOCALAPPDATA%\Programs\スリープ防止ツール"

echo.
echo   スリープ防止ツール  インストーラ
echo   ==================================
echo   インストール先: %DEST%
echo.

rem 起動中なら終了させる
taskkill /f /im "スリープ防止.exe" >nul 2>nul

if not exist "%DEST%" mkdir "%DEST%" 2>nul
copy /y "%~dp0スリープ防止.exe" "%DEST%\スリープ防止.exe" >nul
if errorlevel 1 goto FAIL
if exist "%~dp0アンインストール.bat" copy /y "%~dp0アンインストール.bat" "%DEST%\アンインストール.bat" >nul 2>nul
if exist "%~dp0README.txt" copy /y "%~dp0README.txt" "%DEST%\README.txt" >nul 2>nul

rem ショートカット作成（スタートメニュー＋デスクトップ）
set "VBS=%TEMP%\sg_shortcut.vbs"
> "%VBS%" echo Set s = CreateObject("WScript.Shell")
>> "%VBS%" echo Set l = s.CreateShortcut(s.SpecialFolders("Programs") ^& "\スリープ防止.lnk")
>> "%VBS%" echo l.TargetPath = "%DEST%\スリープ防止.exe"
>> "%VBS%" echo l.WorkingDirectory = "%DEST%"
>> "%VBS%" echo l.Description = "スリープ・画面OFF・自動ロックを一時的に抑止"
>> "%VBS%" echo l.Save
>> "%VBS%" echo Set d = s.CreateShortcut(s.SpecialFolders("Desktop") ^& "\スリープ防止.lnk")
>> "%VBS%" echo d.TargetPath = "%DEST%\スリープ防止.exe"
>> "%VBS%" echo d.WorkingDirectory = "%DEST%"
>> "%VBS%" echo d.Save
cscript //nologo "%VBS%" >nul
del "%VBS%" >nul 2>nul

rem 「設定＞アプリ」からアンインストールできるよう登録（管理者権限は不要）
set "KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\SleepGuardApp"
reg add "%KEY%" /v DisplayName     /t REG_SZ /d "スリープ防止ツール" /f >nul
reg add "%KEY%" /v DisplayVersion  /t REG_SZ /d "1.0.0" /f >nul
reg add "%KEY%" /v Publisher       /t REG_SZ /d "SleepGuard" /f >nul
reg add "%KEY%" /v InstallLocation /t REG_SZ /d "%DEST%" /f >nul
reg add "%KEY%" /v DisplayIcon     /t REG_SZ /d "%DEST%\スリープ防止.exe" /f >nul
reg add "%KEY%" /v UninstallString /t REG_SZ /d "\"%DEST%\アンインストール.bat\"" /f >nul
reg add "%KEY%" /v NoModify        /t REG_DWORD /d 1 /f >nul
reg add "%KEY%" /v NoRepair        /t REG_DWORD /d 1 /f >nul

echo   [完了] インストールしました。
echo.
echo   ・デスクトップとスタートメニューに「スリープ防止」を作成
echo   ・アンインストールは「設定 ＞ アプリ」から、または
echo     %DEST%\アンインストール.bat
echo.
choice /c YN /n /t 8 /d Y /m "  今すぐ起動しますか? (Y/N) "
if errorlevel 2 goto END
start "" "%DEST%\スリープ防止.exe"
goto END

:FAIL
echo.
echo   [失敗] コピーできませんでした。
echo   スリープ防止.exe が同じフォルダにあるか確認してください。
echo.
pause
exit /b 1

:END
echo.
timeout /t 3 >nul
exit /b 0
