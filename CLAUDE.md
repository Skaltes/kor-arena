# Kor Arena - proje notlari

## YETKI (kullanici verdi, sormadan gecerli)
Oyun icin UCRETSIZ her program, arac ve varlik indirilip kullanilabilir. Ucretli abonelik/kredi yok. Kullanici Godot ve Blender 5.2'yi kendi kurdu.

## ANA PROJE: Godot 4 (`godot/` klasoru) - kullanici karari: oncelik gercek 3D oyun
- Editor kurulumsuz: `araclar\Godot_v4.7.2-stable_win64.exe` (kullanicinin indirdigi resmi imzali surum). Tek oyun dosyasi: ana klasorde `Oyna.bat`; editor `araclar\Godot Editoru.bat`. Sonraki tum gelistirmeler bu Oyna.bat'tan gorunur.
- `godot/core/`: sahneye dokunmaz (game_data, rules, battle, brain, icon_library). Battle sabit 30 Hz, tohumlu; komut alir, duz veri olay verir. PvP icin hazir yapi.
- `godot/scripts/`: arena_view, character_view (GLB modele gecince yalniz bu degisir), effects, hud, main.
- KULLANICI KARARLARI: kamera SABIT YAN KAMERA (Doom Forge gibi): savasta hic hareket etmez, surukleme/yakinlastirma/sarsinti YOK, ustten-izometrik-capraz YOK; sol oyuncu/sag rakip, savas alani x=-5..5, arena arkada. Mana YOK, yetenek yalniz bekleme suresiyle sinirli. Otomatik yetenek YOK: oyuncu 1-4 ile basar, basmazsa normal saldiri; rakip AI kendi yeteneklerini kullanir.
- GORSEL (kullanici: MMORPG kalitesi, donanimi yormasin, ASLA ucretli varlik): insan oranli Quaternius karakteri + Universal Animation Library (CC0, `assets/quaternius`). Zirh ve silahlar `tools/build_hero.py` ile Blender'da uretilir (govdeden oyularak birebir oturur): degistirmek icin betigi calistir, `Hero.glb`/`Weapons.glb` yenilenir. Dokular ve gokyuzu Poly Haven CC0 (`assets/pbr`), fontlar OFL (Cinzel, Alegreya), arayuz `art/ui/*.svg`, portreler `-- --portraits=<klasor>` ile uretilir. Mixamo Adobe hesabi ister, kullanilmadi. 40 kare/sn altinda kalite otomatik duser (`set_low_quality`). KayKit dosyalari artik kullanilmiyor.
- Arka plan: SABIT, seyircisiz Roma amfisi (`arena_view.gd`): kum zemin, tas koltuklar, kemerler, savas esyalari; hicbir sey hareket etmez.
- Canli 1v1: VPN/modem ayari YOK, 6 harfli oda koduyla baglanilir. Odayi acan savasi calistirir, katilan komut yollar; mesajlar hesap istemeyen herkese acik MQTT sunuculari uzerinden gider (`scripts/net_session.gd`, sirayla emqx/hivemq/mosquitto; kodun ilk harfi sunucu). Iki oyuncu da kendini solda gorur. noray/tomfol.in KAPALI, ENet+UPnP kaldirildi.
- Her sinifta 6 yetenek (tus 1-6). Isinlanma ve uzun sure hasari engelleyen yetenek YOK; sersemletmeler kisa. Vuruslar yavas ve akici (sinif verisi `aspd`/`swing`, yetenek `windup`).
- Arka plan: SABIT, seyircisiz Roma amfisi (`arena_view.gd`): kum zemin, tas koltuklar, kemerler, savas esyalari; hicbir sey hareket etmez.
- Canli 1v1: VPN/modem ayari YOK, 6 harfli oda koduyla baglanilir. Odayi acan savasi calistirir, katilan komut yollar; mesajlar hesap istemeyen herkese acik MQTT sunuculari uzerinden gider (`scripts/net_session.gd`, sirayla emqx/hivemq/mosquitto; kodun ilk harfi sunucu). Iki oyuncu da kendini solda gorur. noray/tomfol.in KAPALI, ENet+UPnP kaldirildi.
- Her sinifta 6 yetenek (tus 1-6). Isinlanma ve uzun sure hasari engelleyen yetenek YOK; sersemletmeler kisa. Vuruslar yavas ve akici (sinif verisi `aspd`/`swing`, yetenek `windup`).
- Siniflar (kullanici adlari): Paladin (kilic+kalkan, kod `warrior`), Berserker (cift balta, kod `assassin`, silah turu `axe`), Titan (iki elli balyoz, kod `brute`). Buyucu KALDIRILDI.
- Silah vucuda GIRMEZ. TEK GUVENILIR OLCUM: `-- --audit=<klasor>` (`mesh_audit.gd`, gercek model yuzeyi + zirh; `--grip` kapsul olcumu YANILTICI, sorunlari kacirdi). Paladin: kalkan `shield_rig.gd` ile govde onunde durur, sol kol ona cozulur, sag kol yaklasinca yana acilir. Berserker/Paladin kilici: `hand_rig.gd` bilegi disari cevirir. Titan: `sledge_rig.gd _keep_clear`, son soz el temasinda. Sonuc ve kareler `kontrol-goruntuleri/`. Hiz ayari YOK, oyun hizi sabit. Her yetenegin kendi ikonu var (`art/icons/<id>.svg`).
- Su an kapsam: sinif secimi + 1v1 AI savasi (Sv. 8 sabit). Envanter/magaza/seviye henuz web surumunde, Godot'a tasinacak.
- Test: `godot --headless --path godot --script res://tests/test_core.gd`; pencereli kanit: `-- --demo=<klasor>` ekran goruntusu alip kapanir.
- PixelLab: ileride ikon/envanter gorselleri icin. Simdilik ucretli abonelik/kredi KULLANMA. Entegrasyon noktasi `art/icons/<id>.png` (bkz. ICONS.md); kod degismez.
- Ders: CylinderMesh varsayilan kapaklidir, halka icin cap_top/bottom kapat.

- Arkadasa gonderilecek paket: `Arkadasima-Gonder\KorArena-Arkadasima.zip` (exe + Nasil Oynanir.txt). Kod degisince yeniden disa aktar: `godot --headless --path godot --export-release Windows ..\Arkadasima-Gonder\KorArena.exe` (ciktiyi `Select -First` ile kesme, islemi oldurur) ve zip'i yenile.
- Canli mac yalnizca ayni bilgisayardaki iki kopyayla, gercek sunucu uzerinden test edildi; iki ayri evden test HENUZ yapilmadi. Herkese acik sunucular garanti vermez ve yogun anda mesaj dusurur (olculen ~%40): bu yuzden tum onemli mesajlar onaylanana kadar her pakette tekrar yollanir, saniyede en cok 10 paket. Olculen gecikme ~370-490 ms.

- OTOMATIK GUNCELLEME (kullanici istedi): HER OYUN DEGISIKLIGINDEN SONRA `tools\yayinla.ps1 -Not ".."` calistir (surum artar, exe uretir, GitHub `Skaltes/kor-arena` Releases'e yukler, repo herkese acik, kaynak kod yok). Oyuncular acilista `scripts/boot.gd` ile kendini gunceller. Sabit indirme linki: https://github.com/Skaltes/kor-arena/releases/latest/download/KorArena.exe . `gh` kurulu ve girisli; Drive ve Gofile artik kullanilmiyor.
- SAVAS TASARIMI (kullanici: skill spam degil, dogru skill dogru zamanda): `GameData.GCD` ortak bekleme, uzun cooldown, hazirlik cubugu (rakibin ne yaptigi gorunur), kesme (stun/interrupt hazirligi iptal eder), kombolar (`combo` alani, kosul olunca dugme parlar, KOMBO yazisi), oyuncunun yetenegi ortada ikon+adla gosterilir.
- YETENEK TAVSIYESI YOK (kullanici karari): dugme parlatma, "simdi tam zamani" gibi yonlendirme eklenmez; yalnizca simge ve bekleme suresi gorunur.
- Hareket kalitesi: her saldiri uc faz (yavas hazirlik, ani vurus, toparlanma), `character_view.gd MOTIONS`; vurus kareleri `--calib` ile silah ucundan olculdu, `--skills=<klasor>` tum sinif ve yetenekleri olcer. Rakip yere yikilmaz (Hit_Knockback kullanma), geri sarsilir. Isabet parlamalari kucuk tutulur, karakteri kapatmaz.
- Balyoz iki elle: `scripts/sledge_rig.gd` balyozun hareketini kendisi tanimlar, avuc yonu ve parmaklar sapa gore cozulur. KOL BOYU ~49 cm: pozlar bu sinirda tasarlanir, asilirsa balyoz govdeye cekilir ve poz bozulur. Bekleme: gogus onunde capraz; sagdaki savasci `flip` ile aynalanir. Ölcum 0 mm gorunse de `--grip=<klasor>` yakin cekimine bak: temas var ama okunmuyor olabilir. Olcum `-- --sledge=<klasor>`; Godot duzeltilmis pozu yalnizca cizime verir, `get_bone_global_pose` degil BoneAttachment oku.
- DOOM FORGE REFERANSI (ModDB ekran goruntuleri incelendi): karanlik mavi-siyah taş arena, zincir, kan, ates; ALCAK ve YAKIN sabit yan kamera (savascilar ekrani doldurur); uzun yesil can cubuklari + kirmizi hasar izi, `Ad <Klan> [seviye]`, ustte ince ikinci cubuk; altta numarali yetenek sirasi; kanli vuruslar, alevli silah izi; giris: ortada kahraman, sagda sinif, solda ad. Orijinal varliklar KOPYALANMAZ, yalnizca atmosfer alinir. Eksik sistemler: Hero sekmesi, Craft, Hall, Market, stat puani, iksir, gunluk odul, sira/liderlik, klan. Mac sonunda sinif degistirilebilir, canli macta da. Vuruslar yavas (`aspd`, `swing`, `windup`). Yetenekler belirgin: renk, ad yazisi, sarj halkasi, kesik izi (`main.gd SKILL_COLORS`, `effects.gd`).

## Eski tarayici surumu (asagisi): `eski-tarayici-surumu/` klasorunde arsiv; yalnizca icerik/denge referansi.

Doom Forge'dan ilham alan, tarayicida calisan ozgun 3D fantastik arena RPG. Kullanici yazilim bilmiyor: basit Turkce anlat, teknik kararlari sen ver.
Calistirma: `Oyna.bat` (index.html). Kurulum gerekmez; Node yok, derleme adimi yok. Three.js r159 `lib/` icinde yerel.

## Mimari
- `js/data.js`: denge ve icerik (sinif, yetenek, esya, arena). Yeni icerik once buraya.
- `js/rules.js`: stat, esya, rakip, odul. `js/sim.js`: savas motoru ve yapay zeka.
- Bu uc dosya ekrana dokunmaz. Sim tohumlu, sabit adimli (30 Hz); girdi = komut, cikti = olay. Oyuncu ve AI ayni komutlari gonderir.
- PvP yolu: rakip zaten oyuncu bicimli karakter nesnesi; sim sunucuya tasinir, komutlar agdan gelir, olaylar seri hale getirilir (`proj` olayi su an nesne referansi tasiyor, degistirilmeli).
- `js/gfx.js`: Three.js gorunum (modeller kodla uretilir). `js/ui.js`: ekranlar. `js/main.js`: akis, kayit (localStorage), dongu.

## Durum
Calisan: karakter olusturma, 3 sinif, 12 yetenek, 5 arena, seviye/XP/altin, ganimet, envanter, magaza, ekipmanin gorunumu degistirmesi, oto yetenek, hiz x2, kayit.
Sonraki olasi adimlar: ses, gercek animasyonlu modeller, yetenek gelistirme, gorevler, sonra PvP.
Test ipucu: gizli onizleme panelinde kare hizi dusuk gorunur; `DF.game.frame(0.1)` ile elle ilerlet.
