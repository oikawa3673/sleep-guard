// スリープ防止ツール (SleepGuard)
// ONの間だけ スリープ・画面OFF・スクリーンセーバー(自動ロック) を抑止する。
// 負荷を最小にするため、常駐時はタイマー停止＋ワーキングセット圧縮を行う。
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class SleepGuard : Form
{
    [DllImport("kernel32.dll")]
    static extern uint SetThreadExecutionState(uint esFlags);
    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll")]
    static extern bool SetProcessWorkingSetSize(IntPtr h, IntPtr min, IntPtr max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    const uint ES_CONTINUOUS       = 0x80000000;
    const uint ES_SYSTEM_REQUIRED  = 0x00000001;
    const uint ES_DISPLAY_REQUIRED = 0x00000002;
    const byte VK_F15              = 0x7E;   // どのアプリにも影響しない無害なキー
    const uint KEYEVENTF_KEYUP     = 2;

    static readonly Color Navy  = Color.FromArgb(15, 32, 62);
    static readonly Color Blue  = Color.FromArgb(28, 122, 172);
    static readonly Color Red   = Color.FromArgb(150, 60, 50);
    static readonly Color Green = Color.FromArgb(80, 220, 140);

    Label lblState, lblInfo;
    Button btn;
    NotifyIcon tray;
    Timer timer;
    bool isOn;
    DateTime startAt;
    Icon AppIcon;

    // exe自身に埋め込まれたアイコンを取り出す（別ファイルを同梱せずに済む）
    static Icon LoadAppIcon()
    {
        try { return Icon.ExtractAssociatedIcon(Application.ExecutablePath); }
        catch { return SystemIcons.Application; }
    }

    public SleepGuard()
    {
        Text = "スリープ防止";
        ClientSize = new Size(284, 172);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        TopMost = true;
        BackColor = Navy;
        AppIcon = LoadAppIcon();          // exeに埋め込んだアイコン
        Icon = AppIcon;

        lblState = new Label();
        lblState.Text = "OFF";
        lblState.Font = new Font("Meiryo UI", 26F, FontStyle.Bold);
        lblState.ForeColor = Color.Gray;
        lblState.TextAlign = ContentAlignment.MiddleCenter;
        lblState.SetBounds(7, 10, 270, 52);
        Controls.Add(lblState);

        lblInfo = new Label();
        lblInfo.Text = "スリープ・画面OFF・自動ロックを抑止します";
        lblInfo.Font = new Font("Meiryo UI", 8F);
        lblInfo.ForeColor = Color.FromArgb(180, 200, 220);
        lblInfo.TextAlign = ContentAlignment.MiddleCenter;
        lblInfo.SetBounds(7, 62, 270, 34);
        Controls.Add(lblInfo);

        btn = new Button();
        btn.Text = "ON にする";
        btn.Font = new Font("Meiryo UI", 12F, FontStyle.Bold);
        btn.SetBounds(17, 100, 250, 46);
        btn.FlatStyle = FlatStyle.Flat;
        btn.BackColor = Blue;
        btn.ForeColor = Color.White;
        btn.Click += delegate { Toggle(!isOn); };
        Controls.Add(btn);

        tray = new NotifyIcon();
        tray.Icon = Icon;
        tray.Text = "スリープ防止: OFF";
        tray.Visible = true;
        ContextMenuStrip menu = new ContextMenuStrip();
        menu.Items.Add("画面を表示", null, delegate { ShowWindowAgain(); });
        menu.Items.Add("ON / OFF 切替", null, delegate { Toggle(!isOn); });
        menu.Items.Add("終了", null, delegate { Close(); });
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += delegate { ShowWindowAgain(); };

        // 4分ごと。一般的なスクリーンセーバー発動時間(5〜10分)より十分短い。
        // OFFの間はタイマーを止めるので、待機中のCPU使用はゼロ。
        timer = new Timer();
        timer.Interval = 240000;
        timer.Tick += delegate { Nudge(); };

        Resize += delegate { if (WindowState == FormWindowState.Minimized) { Hide(); Trim(); } };
        Shown += delegate { Trim(); };
        FormClosing += delegate {
            timer.Stop();
            SetThreadExecutionState(ES_CONTINUOUS);   // 抑止を必ず解除
            tray.Visible = false;
            tray.Dispose();
        };
    }

    void ShowWindowAgain()
    {
        Show();
        WindowState = FormWindowState.Normal;
        Activate();
    }

    // 無操作時間をリセットして自動ロックを防ぐ
    void Nudge()
    {
        keybd_event(VK_F15, 0, 0, UIntPtr.Zero);
        keybd_event(VK_F15, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        int m = (int)(DateTime.Now - startAt).TotalMinutes;
        lblInfo.Text = "抑止中… 経過 " + m + " 分\n席を離れるときは OFF か Win+L";
        Trim();
    }

    void Toggle(bool on)
    {
        isOn = on;
        if (on)
        {
            startAt = DateTime.Now;
            SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
            timer.Start();
            lblState.Text = "ON";
            lblState.ForeColor = Green;
            lblInfo.Text = "抑止中… 経過 0 分\n席を離れるときは OFF か Win+L";
            btn.Text = "OFF にする";
            btn.BackColor = Red;
            tray.Text = "スリープ防止: ON";
            tray.Icon = MakeIcon(Green);
        }
        else
        {
            timer.Stop();
            SetThreadExecutionState(ES_CONTINUOUS);
            lblState.Text = "OFF";
            lblState.ForeColor = Color.Gray;
            lblInfo.Text = "スリープ・画面OFF・自動ロックを抑止します";
            btn.Text = "ON にする";
            btn.BackColor = Blue;
            tray.Text = "スリープ防止: OFF";
            tray.Icon = MakeIcon(Color.Gray);
        }
        Trim();
    }

    // 使っていないメモリをOSへ返す（常駐中のRAMを数MBに抑える）
    void Trim()
    {
        GC.Collect();
        GC.WaitForPendingFinalizers();
        SetProcessWorkingSetSize(GetCurrentProcess(), (IntPtr)(-1), (IntPtr)(-1));
    }

    // アプリアイコンに状態ランプ(緑=ON / 灰=OFF)を重ねたトレイ用アイコンを作る
    Icon MakeIcon(Color c)
    {
        using (Bitmap bmp = new Bitmap(16, 16))
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            g.Clear(Color.Transparent);
            if (AppIcon != null) g.DrawIcon(AppIcon, new Rectangle(0, 0, 16, 16));
            // 右下に状態ランプ（白フチ付きで小さくても見える）
            using (SolidBrush w = new SolidBrush(Color.White)) g.FillEllipse(w, 8, 8, 8, 8);
            using (SolidBrush b = new SolidBrush(c))          g.FillEllipse(b, 9, 9, 6, 6);
            return Icon.FromHandle(bmp.GetHicon());
        }
    }

    [STAThread]
    static void Main()
    {
        // 二重起動を防ぐ（無駄な常駐を増やさない）
        bool isNew;
        using (System.Threading.Mutex mtx = new System.Threading.Mutex(true, "SleepGuard_SingleInstance", out isNew))
        {
            if (!isNew)
            {
                // 既に起動中なら、その画面を前面に出して静かに終了する
                IntPtr h = FindWindow(null, "スリープ防止");
                if (h != IntPtr.Zero) { ShowWindow(h, 9 /* SW_RESTORE */); SetForegroundWindow(h); }
                return;
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SleepGuard());
        }
    }
}
