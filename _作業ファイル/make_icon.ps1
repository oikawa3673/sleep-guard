# Designer.png から マルチサイズ .ico を生成する
# ・四隅の白い余白を透過にする
# ・16/24/32/48/64/128/256 px を1つのicoに束ねる（PNG圧縮формат）
Add-Type -AssemblyName System.Drawing

$src = 'C:\Users\3673\Desktop\Designer.png'
$dst = 'C:\Users\3673\Desktop\.claude\projects\スリープ防止ツール\_作業ファイル\app.ico'

$orig = [System.Drawing.Bitmap]::FromFile($src)

# 1) 白背景を透過にする（角の白を基準に近似色を抜く）
$work = New-Object System.Drawing.Bitmap($orig.Width, $orig.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($work)
$g.DrawImage($orig, 0, 0, $orig.Width, $orig.Height)
$g.Dispose()
for ($y = 0; $y -lt $work.Height; $y++) {
    for ($x = 0; $x -lt $work.Width; $x++) {
        $p = $work.GetPixel($x, $y)
        if ($p.R -ge 246 -and $p.G -ge 246 -and $p.B -ge 246) {
            # 白に近い画素のうち、外周から連続している部分だけ透過にしたいが、
            # このアイコンは白背景が四隅のみなので、外周からの距離で判定する
            $edge = ($x -lt 40 -or $y -lt 40 -or $x -ge $work.Width - 40 -or $y -ge $work.Height - 40)
            if ($edge) { $work.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 255, 255, 255)) }
        }
    }
}

# 2) 各サイズへ高品質縮小
$sizes = @(16, 24, 32, 48, 64, 128, 256)
$pngs = @()
foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gr = [System.Drawing.Graphics]::FromImage($bmp)
    $gr.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gr.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gr.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gr.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $gr.Clear([System.Drawing.Color]::Transparent)
    $gr.DrawImage($work, (New-Object System.Drawing.Rectangle(0, 0, $s, $s)))
    $gr.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += ,($ms.ToArray())
    $bmp.Dispose()
    $ms.Dispose()
}
$work.Dispose()
$orig.Dispose()

# 3) ICOコンテナを手組みする（各画像はPNGのまま格納＝Vista以降の標準形式）
$fs = New-Object System.IO.FileStream($dst, [System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([uint16]0)               # reserved
$bw.Write([uint16]1)               # type = icon
$bw.Write([uint16]$sizes.Count)    # count
$offset = 6 + (16 * $sizes.Count)
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]
    $bw.Write([byte]$(if ($s -ge 256) { 0 } else { $s }))   # width  (0 = 256)
    $bw.Write([byte]$(if ($s -ge 256) { 0 } else { $s }))   # height
    $bw.Write([byte]0)             # palette
    $bw.Write([byte]0)             # reserved
    $bw.Write([uint16]1)           # color planes
    $bw.Write([uint16]32)          # bits per pixel
    $bw.Write([uint32]$pngs[$i].Length)
    $bw.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Flush(); $bw.Close(); $fs.Close()

$info = Get-Item $dst
Write-Output ("ICO生成: " + [math]::Round($info.Length/1KB,1) + " KB  サイズ数=" + $sizes.Count)
