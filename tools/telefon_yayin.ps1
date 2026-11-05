# Hazir exe'yi GitHub'a yeni surum olarak yukler, telefon sayfasini yayinlar ve GitHub Pages'i acar.
# Surum numarasi godot\core\version.gd icindeki BUILD'den okunur; exe o surumle uretilmis olmalidir.
# Surum notu Arkadasima-Gonder\surum_notu.txt dosyasindan alinir.
$ErrorActionPreference = 'Stop'
$kok = Split-Path $PSScriptRoot -Parent
$d = "$kok\Arkadasima-Gonder"
$gh = 'C:\Program Files\GitHub CLI\gh.exe'
$metin = [IO.File]::ReadAllText("$kok\godot\core\version.gd")
$surum = [int]([regex]::Match($metin, 'const BUILD := (\d+)').Groups[1].Value)
$kayit = "$d\yayin_kaydi.txt"
"Surum $surum yayinlaniyor." | Tee-Object -FilePath $kayit

# GitHub girisi bu pencerede gorunmuyorsa kullanici tarayicida bir kez giris yapar (sifre buraya yazilmaz).
$ErrorActionPreference = 'Continue'
$null = & $gh auth status --hostname github.com 2>&1
if ($LASTEXITCODE -ne 0) {
    ""
    "GitHub girisi gerekiyor. Ekrandaki 8 haneli kodu not et, Enter'a bas;"
    "acilan GitHub sayfasina kodu yazip Skaltes hesabiyla onayla."
    & $gh auth login --hostname github.com --git-protocol https --web
    $null = & $gh auth status --hostname github.com 2>&1
    if ($LASTEXITCODE -ne 0) { throw "GitHub girisi yapilamadi." }
    "GitHub girisi tamam." | Tee-Object -FilePath $kayit -Append
}

# Ayni surum zaten yayindaysa ikinci kez yuklenmez (yarim kalan onceki denemeden sonra da guvenli).
$null = & $gh release view "v$surum" --repo Skaltes/kor-arena 2>&1
$var = $LASTEXITCODE -eq 0
$ErrorActionPreference = 'Stop'
if ($var) {
    "v$surum zaten GitHub'da var, exe yeniden yuklenmiyor." | Tee-Object -FilePath $kayit -Append
} else {
    if (Test-Path "$d\KorArena.zip") { [IO.File]::Delete("$d\KorArena.zip") }
    Compress-Archive -LiteralPath "$d\KorArena.exe" -DestinationPath "$d\KorArena.zip"
    [IO.File]::WriteAllText("$d\surum.txt", "$surum", [Text.UTF8Encoding]::new($false))
    $notlar = "Kor Arena $surum"
    if (Test-Path "$d\surum_notu.txt") { $notlar = [IO.File]::ReadAllText("$d\surum_notu.txt") }
    [IO.File]::WriteAllText("$env:TEMP\kor_notlar.txt", $notlar, [Text.UTF8Encoding]::new($false))
    # Yukleme hatasi pencere kapansa da okunabilsin diye kayda yazilir.
    $komut = "$env:TEMP\kor_surum.cmd"
    $satir = "@`"$gh`" release create v$surum `"$d\KorArena.exe`" `"$d\KorArena.zip`" `"$d\surum.txt`" --repo Skaltes/kor-arena --title `"Kor Arena $surum`" --notes-file `"$env:TEMP\kor_notlar.txt`" --latest 2>&1"
    [IO.File]::WriteAllText($komut, $satir, [Text.ASCIIEncoding]::new())
    "Yukleniyor, internet hizina gore birkac dakika surebilir..."
    & cmd /c $komut | Tee-Object -FilePath $kayit -Append
    if ($LASTEXITCODE -ne 0) { throw "Surum yuklenemedi. Ayrinti: $kayit" }
}
& "$PSScriptRoot\web_yayinla.ps1" | Tee-Object -FilePath $kayit -Append
$ErrorActionPreference = 'Continue'
# Telefon sayfasi yalniz ilk yayinda acilir; aciksa tekrar acmaya calisilmaz (zararsiz ama kirmizi uyari veriyordu).
$null = & $gh api repos/Skaltes/kor-arena/pages 2>&1
if ($LASTEXITCODE -ne 0) {
    & $gh api repos/Skaltes/kor-arena/pages -X POST -f "source[branch]=gh-pages" -f "source[path]=/" --jq .html_url 2>&1 | Tee-Object -FilePath $kayit -Append
}
""
"BITTI. Surum $surum. Telefon baglantisi birkac dakika icinde acilir:" | Tee-Object -FilePath $kayit -Append
"https://skaltes.github.io/kor-arena/"
