# Telefon/tarayici surumunu uretir ve GitHub Pages'e yukler: https://skaltes.github.io/kor-arena/
# gh-pages dalinda yalnizca son surumun dosyalari durur; her yayinda dal bastan yazilir, boylece depo sismez.
# GitHub tek dosyada 100 MB'i kabul etmez. Model dokulari PC'de kayipsiz ve buyuk oldugu icin telefon surumu projenin
# GECICI KOPYASINDAN uretilir: kopyada 3B dokular (modeller, arena, gokyuzu) 1024 piksele indirilip sikistirilir. PC surumu ve asil proje degismez.
param([switch]$SadeceUret) # -SadeceUret: yalniz Arkadasima-Gonder/web icine uretir, YUKLEMEZ (yerel deneme)
$ErrorActionPreference = 'Stop'
$kok = Split-Path $PSScriptRoot -Parent
$godot = "$kok\araclar\Godot_v4.7.2-stable_win64_console.exe"
$git = 'C:\Program Files\Git\cmd\git.exe'
$web = "$kok\Arkadasima-Gonder\web"
$kopya = "$env:TEMP\korarena_web_kopya"
$TEL_DOKU = 1024

# git nesne dosyalari salt-okunurdur; [IO.Directory]::Delete onlari silemez, -Force siler.
function Sil($yol) { if (Test-Path -LiteralPath $yol) { Remove-Item -LiteralPath $yol -Recurse -Force } }
Sil $web
$null = New-Item -ItemType Directory $web

# proje kopyasi (onbellek de kopyalanir, yalniz degisen dokular yeniden islenir)
$null = robocopy "$kok\godot" $kopya /MIR /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw "Proje kopyalanamadi (robocopy $LASTEXITCODE)" }
$utf8 = [Text.UTF8Encoding]::new($false)
foreach ($f in Get-ChildItem "$kopya\assets\sketchfab", "$kopya\assets\pbr", "$kopya\assets\quaternius" -Recurse -Include *.png.import, *.jpg.import, *.hdr.import) {
    $t = [IO.File]::ReadAllText($f.FullName)
    if ($f.Name -notlike "*.hdr.import") { $t = $t -replace 'compress/mode=\d', 'compress/mode=2' } # gokyuzu HDR kayipsiz kalir, yalniz kuculur
    # Dokular hem bilgisayar hem telefon bicimiyle paketlenir (yalniz telefon bicimi bilgisayar tarayicisinda kararti).
    # Yer kazanmak icin renk dokusu 1024, yardimci haritalar (normal, puruzluluk, metal) 512 piksel.
    $sinir = if ($f.Name -match 'baseColor|albedo|_BaseColor|Superhero_Male_Dark') { $TEL_DOKU } else { $TEL_DOKU / 2 }
    $t = $t -replace 'process/size_limit=\d+', "process/size_limit=$sinir" -replace 'mipmaps/generate=false', 'mipmaps/generate=true'
    [IO.File]::WriteAllText($f.FullName, $t, $utf8)
}
$ErrorActionPreference = 'Continue' # Godot'nun uyari satirlari betigi durdurmasin; sonuc asagida dosyadan denetlenir
$null = & $godot --headless --path $kopya --import 2>&1 | ForEach-Object { "$_" }
$null = & $godot --headless --path $kopya --export-release "Web" "$web\index.html" 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = 'Stop'
if (-not (Test-Path "$web\index.wasm")) { throw 'Web disa aktarma basarisiz' }
Copy-Item "$PSScriptRoot\web\*" $web -Force
$null = New-Item -ItemType File "$web\.nojekyll" -Force
$buyuk = Get-ChildItem $web -File | Where-Object { $_.Length -gt 95MB }
if ($buyuk) { throw ("GitHub siniri asildi (100 MB): " + (($buyuk | ForEach-Object { "{0} {1:N0} MB" -f $_.Name, ($_.Length / 1MB) }) -join ", ")) }
"Telefon dosyalari: " + ((Get-ChildItem $web -File | Sort-Object Length -Descending | Select-Object -First 3 | ForEach-Object { "{0} {1:N0} MB" -f $_.Name, ($_.Length / 1MB) }) -join ", ")

if ($SadeceUret) { "URETILDI (yuklenmedi): $web"; return }
$adres = (& $git -C $kok remote get-url origin)
Push-Location $web
$ErrorActionPreference = 'Continue' # git'in satir sonu uyarilari hata sayilmasin; basari cikis koduyla denetlenir
try {
    & $git init -q -b gh-pages 2>&1 | Out-Null
    & $git add -A 2>&1 | Out-Null
    & $git -c user.name="Skaltes" -c user.email="350876651+Skaltes@users.noreply.github.com" commit -q -m "Kor Arena web surumu`n`nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" 2>&1 | Out-Null
    $cikti = & $git push -q -f $adres gh-pages 2>&1 | ForEach-Object { "$_" }
    $kod = $LASTEXITCODE
} finally {
    Pop-Location
    Sil "$web\.git"
}
$ErrorActionPreference = 'Stop'
if ($kod -ne 0) { throw ("Web yuklenemedi: " + ($cikti -join " ")) }
"WEB YAYINLANDI"
