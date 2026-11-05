# Yeni surumu yayinlar: surum numarasini artirir, exe uretir, GitHub'a yukler.
# Oyuncularin oyunu bir sonraki acilista kendiliginden guncellenir.
# Calistirma: tools\yayinla.ps1 -Not "Ne degisti"
param([string]$Not = "Guncelleme", [string]$Cikti = "")
$ErrorActionPreference = 'Stop'
$kok = Split-Path $PSScriptRoot -Parent
$godot = "$kok\araclar\Godot_v4.7.2-stable_win64_console.exe"
$gh = 'C:\Program Files\GitHub CLI\gh.exe'
$dosya = "$kok\godot\core\version.gd"
$utf8 = [Text.UTF8Encoding]::new($false)

$metin = [IO.File]::ReadAllText($dosya)
$eski = [int]([regex]::Match($metin, 'const BUILD := (\d+)').Groups[1].Value)
$yeni = $eski + 1
[IO.File]::WriteAllText($dosya, $metin.Replace("const BUILD := $eski", "const BUILD := $yeni"), $utf8)
$repo = [regex]::Match($metin, 'const REPO := "([^"]+)"').Groups[1].Value

$dis = "$kok\Arkadasima-Gonder"
if (Test-Path "$dis\KorArena.exe") { Remove-Item -LiteralPath "$dis\KorArena.exe" -Force -Confirm:$false }
$null = & $godot --headless --path "$kok\godot" --import 2>&1 | ForEach-Object { "$_" }
$null = & $godot --headless --path "$kok\godot" --export-release "Windows" "$dis\KorArena.exe" 2>&1 | ForEach-Object { "$_" }
if (-not (Test-Path "$dis\KorArena.exe")) { throw 'Disa aktarma basarisiz' }
if (Test-Path "$dis\KorArena.zip") { Remove-Item -LiteralPath "$dis\KorArena.zip" -Force -Confirm:$false }
Compress-Archive -LiteralPath "$dis\KorArena.exe" -DestinationPath "$dis\KorArena.zip"
[IO.File]::WriteAllText("$dis\surum.txt", "$yeni", $utf8)
& $gh release create "v$yeni" "$dis\KorArena.exe" "$dis\KorArena.zip" "$dis\surum.txt" --repo $repo --title "Kor Arena $yeni" --notes $Not --latest
& "$PSScriptRoot\web_yayinla.ps1"
"YAYINLANDI: surum $yeni"
