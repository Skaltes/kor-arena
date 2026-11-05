class_name Version
## Oyunun surumu. tools\yayinla.ps1 her yayinda BUILD'i artirir; acilis ekrani GitHub'daki surumle karsilastirir.

const BUILD := 21
const REPO := "Skaltes/kor-arena"
static var force_phone := false # yalnizca gelistirici testi: telefon arayuzunu bilgisayarda dener


## Telefon tarayicisinda acildi mi: dokunmatik arayuz ve hafif goruntu buna gore secilir.
static func phone() -> bool:
	return force_phone or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func url(file: String) -> String:
	return "https://github.com/%s/releases/latest/download/%s" % [REPO, file]
