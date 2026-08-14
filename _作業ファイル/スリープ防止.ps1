# スリープ／スクリーンセーバー防止ツール
# ONの間だけ、画面OFF・スリープ・スクリーンセーバー(自動ロック)を抑止する。
# 席を離れるときは必ずOFFにするか、Win+L で手動ロックすること。

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$sig = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern uint SetThreadExecutionState(uint esFlags);
[DllImport("user32.dll")]
public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
$api = Add-Type -MemberDefinition $sig -Name 'Awake' -Namespace 'Win32' -PassThru

$ES_CONTINUOUS       = [uint32]'0x80000000'
$ES_SYSTEM_REQUIRED  = [uint32]'0x00000001'
$ES_DISPLAY_REQUIRED = [uint32]'0x00000002'
$VK_F15              = [byte]0x7E   # 何のアプリにも影響しない無害なキー
$KEYEVENTF_KEYUP     = [uint32]2

$script:isOn    = $false
$script:startAt = $null

# ---------- 画面 ----------
$form                 = New-Object System.Windows.Forms.Form
$form.Text            = 'スリープ防止'
$form.Size            = New-Object System.Drawing.Size(300, 210)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox     = $false
$form.StartPosition   = 'CenterScreen'
$form.TopMost         = $true
$form.BackColor       = [System.Drawing.Color]::FromArgb(15, 32, 62)   # TCloudネイビー

$lblState           = New-Object System.Windows.Forms.Label
$lblState.Text      = 'OFF'
$lblState.Font      = New-Object System.Drawing.Font('Meiryo UI', 26, [System.Drawing.FontStyle]::Bold)
$lblState.ForeColor = [System.Drawing.Color]::Gray
$lblState.TextAlign = 'MiddleCenter'
$lblState.Size      = New-Object System.Drawing.Size(270, 55)
$lblState.Location  = New-Object System.Drawing.Point(8, 12)
$form.Controls.Add($lblState)

$lblInfo           = New-Object System.Windows.Forms.Label
$lblInfo.Text      = 'スリープ・画面OFF・自動ロックを抑止します'
$lblInfo.Font      = New-Object System.Drawing.Font('Meiryo UI', 8)
$lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(180, 200, 220)
$lblInfo.TextAlign = 'MiddleCenter'
$lblInfo.Size      = New-Object System.Drawing.Size(270, 34)
$lblInfo.Location  = New-Object System.Drawing.Point(8, 68)
$form.Controls.Add($lblInfo)

$btn           = New-Object System.Windows.Forms.Button
$btn.Text      = 'ON にする'
$btn.Font      = New-Object System.Drawing.Font('Meiryo UI', 12, [System.Drawing.FontStyle]::Bold)
$btn.Size      = New-Object System.Drawing.Size(250, 46)
$btn.Location  = New-Object System.Drawing.Point(18, 106)
$btn.FlatStyle = 'Flat'
$btn.BackColor = [System.Drawing.Color]::FromArgb(28, 122, 172)        # TCloudブルー
$btn.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($btn)

# ---------- タスクトレイ ----------
$tray             = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon        = [System.Drawing.SystemIcons]::Application
$tray.Text        = 'スリープ防止: OFF'
$tray.Visible     = $true
$menu             = New-Object System.Windows.Forms.ContextMenuStrip
$miShow           = $menu.Items.Add('画面を表示')
$miQuit           = $menu.Items.Add('終了')
$tray.ContextMenuStrip = $menu
$miShow.add_Click({ $form.Show(); $form.WindowState = 'Normal'; $form.Activate() })
$miQuit.add_Click({ $form.Close() })
$tray.add_DoubleClick({ $form.Show(); $form.WindowState = 'Normal'; $form.Activate() })

# ---------- 定期的に無害なキーを送り、アイドル時間をリセット ----------
$timer          = New-Object System.Windows.Forms.Timer
$timer.Interval = 50000    # 50秒ごと（スクリーンセーバー発動前に必ずリセット）
$timer.add_Tick({
    $api::keybd_event($VK_F15, 0, 0, [UIntPtr]::Zero)
    $api::keybd_event($VK_F15, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
    $api::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED) | Out-Null
    $mins = [int]((Get-Date) - $script:startAt).TotalMinutes
    $lblInfo.Text = "抑止中… 経過 $mins 分`n席を離れるときは OFF か Win+L"
})

function Set-Awake([bool]$on) {
    $script:isOn = $on
    if ($on) {
        $script:startAt = Get-Date
        $api::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED) | Out-Null
        $timer.Start()
        $lblState.Text      = 'ON'
        $lblState.ForeColor = [System.Drawing.Color]::FromArgb(80, 220, 140)
        $lblInfo.Text       = "抑止中… 経過 0 分`n席を離れるときは OFF か Win+L"
        $btn.Text           = 'OFF にする'
        $btn.BackColor      = [System.Drawing.Color]::FromArgb(150, 60, 50)
        $tray.Text          = 'スリープ防止: ON'
    } else {
        $timer.Stop()
        $api::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null   # 抑止を解除
        $lblState.Text      = 'OFF'
        $lblState.ForeColor = [System.Drawing.Color]::Gray
        $lblInfo.Text       = 'スリープ・画面OFF・自動ロックを抑止します'
        $btn.Text           = 'ON にする'
        $btn.BackColor      = [System.Drawing.Color]::FromArgb(28, 122, 172)
        $tray.Text          = 'スリープ防止: OFF'
    }
}

$btn.add_Click({ Set-Awake (-not $script:isOn) })

# 最小化したらトレイへ格納
$form.add_Resize({ if ($form.WindowState -eq 'Minimized') { $form.Hide() } })

# 終了時は必ず抑止を解除（放置事故の防止）
$form.add_FormClosing({
    $timer.Stop()
    $api::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
    $tray.Visible = $false
    $tray.Dispose()
})

# 隠し起動(-WindowStyle Hidden / VBS)で開いてもフォームは必ず表示する
$form.Add_Shown({
    [void]$api::ShowWindow($form.Handle, 5)   # SW_SHOW
    $form.WindowState = 'Normal'
    $form.Activate()
})

[void]$form.ShowDialog()
