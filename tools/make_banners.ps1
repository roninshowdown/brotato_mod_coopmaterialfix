Add-Type -AssemblyName System.Drawing
# Regenerates the Workshop/README section banners in assets/.
# Usage: powershell -ExecutionPolicy Bypass -File tools/make_banners.ps1
$outDir = Join-Path (Split-Path $PSScriptRoot -Parent) "assets"
New-Item -ItemType Directory -Force $outDir | Out-Null

$fontName = "Impact"
if (-not ([System.Drawing.FontFamily]::Families | Where-Object { $_.Name -eq $fontName })) { $fontName = "Arial Black" }

$banners = @(
    @{ file = "banner_problem.png";    text = "THE PROBLEM";         color = "#ff4a3d" },
    @{ file = "banner_fix.png";        text = "WHAT THIS MOD FIXES"; color = "#7dff3a" },
    @{ file = "banner_characters.png"; text = "AFFECTED CHARACTERS"; color = "#7dff3a" },
    @{ file = "banner_ui.png";         text = "IN-GAME LABEL";       color = "#7dff3a" },
    @{ file = "banner_compat.png";     text = "COMPATIBILITY";       color = "#7dff3a" }
)

$W = 1200; $H = 170
foreach ($b in $banners) {
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"
    $g.TextRenderingHint = "AntiAliasGridFit"

    # dark slate background with subtle vertical gradient
    $rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.ColorTranslator]::FromHtml("#3a3d3f")), ([System.Drawing.ColorTranslator]::FromHtml("#26282a")), 90
    $g.FillRectangle($bg, $rect)

    $accent = [System.Drawing.ColorTranslator]::FromHtml($b.color)

    # glowing underline
    for ($i = 6; $i -ge 1; $i--) {
        $a = [int](18 * (7 - $i))
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($a, $accent)), ($i * 3)
        $g.DrawLine($pen, 150, 140, $W - 150, 140)
        $pen.Dispose()
    }
    $solid = New-Object System.Drawing.Pen $accent, 5
    $g.DrawLine($solid, 150, 140, $W - 150, 140)

    # text as path: thick dark outline, then accent fill
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fam = New-Object System.Drawing.FontFamily $fontName
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = "Center"; $sf.LineAlignment = "Center"
    $textRect = New-Object System.Drawing.RectangleF 0, 0, $W, 135
    $path.AddString($b.text, $fam, [int][System.Drawing.FontStyle]::Regular, 96, $textRect, $sf)

    $outline = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 17, 17, 17)), 14
    $outline.LineJoin = "Round"
    $g.DrawPath($outline, $path)
    $fill = New-Object System.Drawing.SolidBrush $accent
    $g.FillPath($fill, $path)
    $hi = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 255, 255, 255)), 2
    $g.DrawPath($hi, $path)

    $bmp.Save((Join-Path $outDir $b.file), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

Get-ChildItem $outDir | ForEach-Object { "{0} {1:N0} KB" -f $_.Name, ($_.Length / 1KB) }
"font: $fontName"
