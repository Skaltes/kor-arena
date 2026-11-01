class_name Version
## Oyunun surumu. tools\yayinla.ps1 her yayinda BUILD'i artirir; acilis ekrani GitHub'daki surumle karsilastirir.

const BUILD := 10
const REPO := "Skaltes/kor-arena"


static func url(file: String) -> String:
	return "https://github.com/%s/releases/latest/download/%s" % [REPO, file]
