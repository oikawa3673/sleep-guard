' スリープ防止ツール 起動用（黒いコンソール画面を出さずに起動する）
' このファイルをダブルクリックして使う。ショートカットを作ってデスクトップに置くと便利。
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")
ps1 = fso.GetParentFolderName(WScript.ScriptFullName) & "\スリープ防止.ps1"
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """", 0, False
