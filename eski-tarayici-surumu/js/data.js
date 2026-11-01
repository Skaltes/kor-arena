// Oyunun tum dengesi ve icerigi burada: sinif, yetenek, esya, arena.
// Kural: bu dosya ve sim.js ekrana/tarayiciya dokunmaz; ileride ayni kod sunucuda calisabilir (PvP).
window.DF = window.DF || {};

DF.CLASSES = {
  warrior: {
    name: 'Savaşçı', desc: 'Ağır zırhlı ön saf. Yüksek can, sersemletme ve yakın alan hasarı.',
    main: 'str', range: 2.1, aspd: 0.95, speed: 4.6,
    base: { str: 12, agi: 6, int: 3, vit: 12 }, grow: { str: 3, agi: 1, int: 0.5, vit: 2.6 },
    skills: ['power', 'bash', 'cry', 'whirl'], weapons: ['sword', 'axe'], color: 0xb5482e,
  },
  assassin: {
    name: 'Suikastçı', desc: 'Hızlı ve ölümcül. Kritik vuruş, zehir ve gölgelerden saldırı.',
    main: 'agi', range: 1.9, aspd: 1.3, speed: 5.4,
    base: { str: 6, agi: 13, int: 4, vit: 8 }, grow: { str: 1.2, agi: 3, int: 0.7, vit: 1.9 },
    skills: ['backstab', 'poison', 'shadow', 'evade'], weapons: ['dagger'], color: 0x3e7a5e,
  },
  mage: {
    name: 'Büyücü', desc: 'Uzaktan yıkım. Düşük can, yüksek alan hasarı ve büyü kalkanı.',
    main: 'int', range: 7.5, aspd: 0.8, speed: 4.3, ranged: true,
    base: { str: 3, agi: 6, int: 15, vit: 9 }, grow: { str: 0.5, agi: 1, int: 3.5, vit: 2.1 },
    skills: ['fireball', 'nova', 'barrier', 'meteor'], weapons: ['staff'], color: 0x4a57b8,
  },
};

// kind: melee | proj | aoe_self | aoe_ground | self | dash
DF.SKILLS = {
  power:    { name: 'Güçlü Darbe',   icon: '⚔', unlock: 1, cd: 5,  mana: 15, kind: 'melee', range: 2.4, mult: 2.2, desc: 'Hedefe ağır bir darbe indirir.' },
  bash:     { name: 'Kalkan Vuruşu', icon: '🛡', unlock: 3, cd: 9,  mana: 20, kind: 'melee', range: 2.4, mult: 1.0, stun: 1.6, desc: 'Hedefi 1.6 sn sersemletir.' },
  cry:      { name: 'Savaş Narası',  icon: '📣', unlock: 5, cd: 18, mana: 25, kind: 'self', buff: { atk: 0.35, def: 0.25, dur: 8 }, desc: '8 sn saldırı +%35, savunma +%25.' },
  whirl:    { name: 'Kasırga',       icon: '🌀', unlock: 8, cd: 12, mana: 35, kind: 'aoe_self', radius: 3.4, mult: 2.0, desc: 'Çevredeki tüm düşmanları biçer.' },

  backstab: { name: 'Arkadan Bıçak', icon: '🗡', unlock: 1, cd: 6,  mana: 15, kind: 'melee', range: 2.2, mult: 1.9, forceCrit: true, desc: 'Her zaman kritik vuran saldırı.' },
  poison:   { name: 'Zehirli Bıçak', icon: '☠', unlock: 3, cd: 8,  mana: 18, kind: 'melee', range: 2.2, mult: 0.8, dot: { mult: 0.4, dur: 6 }, desc: '6 sn boyunca zehir hasarı verir.' },
  shadow:   { name: 'Gölge Adımı',   icon: '🌑', unlock: 5, cd: 10, mana: 22, kind: 'dash', range: 9, mult: 1.5, desc: 'Hedefin arkasına ışınlanıp vurur.' },
  evade:    { name: 'Kaçınma',       icon: '💨', unlock: 8, cd: 16, mana: 25, kind: 'self', buff: { dodge: 1, dur: 3 }, desc: '3 sn tüm saldırılardan kaçar.' },

  fireball: { name: 'Ateş Topu',     icon: '🔥', unlock: 1, cd: 4,  mana: 18, kind: 'proj', range: 9.5, mult: 2.1, speed: 14, fx: 'fire', desc: 'Hedefe alev topu fırlatır.' },
  nova:     { name: 'Buz Halkası',   icon: '❄', unlock: 3, cd: 10, mana: 28, kind: 'aoe_self', radius: 4.2, mult: 1.0, slow: { pct: 0.5, dur: 4 }, desc: 'Çevreyi dondurur, %50 yavaşlatır.' },
  barrier:  { name: 'Büyü Kalkanı',  icon: '🔮', unlock: 5, cd: 16, mana: 30, kind: 'self', shield: 3.2, dur: 10, desc: 'Hasarı emen bir kalkan oluşturur.' },
  meteor:   { name: 'Göktaşı',       icon: '☄', unlock: 8, cd: 15, mana: 45, kind: 'aoe_ground', range: 10, radius: 3.6, mult: 4.0, delay: 1.2, desc: '1.2 sn sonra hedef bölgeye düşer.' },
};

DF.SLOTS = { weapon: 'Silah', helmet: 'Miğfer', armor: 'Zırh', accessory: 'Aksesuar' };

DF.RARITY = [
  { id: 0, name: 'Sıradan',   color: '#b9b4a8', mult: 1.0,  bonus: 0, price: 1 },
  { id: 1, name: 'Sağlam',    color: '#62c56b', mult: 1.25, bonus: 1, price: 1.8 },
  { id: 2, name: 'Nadir',     color: '#4e9df0', mult: 1.6,  bonus: 2, price: 3.5 },
  { id: 3, name: 'Destansı',  color: '#b76cf2', mult: 2.1,  bonus: 3, price: 7 },
  { id: 4, name: 'Efsanevi',  color: '#f6a23a', mult: 2.8,  bonus: 4, price: 15 },
];

DF.ITEM_BASES = {
  sword:  ['Kılıç', 'Uzun Kılıç', 'Pala'],
  axe:    ['Balta', 'Savaş Baltası', 'Teber'],
  dagger: ['Hançer', 'Kama', 'Çift Hançer'],
  staff:  ['Asa', 'Kristal Asa', 'Kadim Asa'],
  helmet: ['Başlık', 'Miğfer', 'Tolga', 'Taç'],
  armor:  ['Yelek', 'Zırh', 'Plaka Zırh', 'Savaş Giysisi'],
  accessory: ['Kolye', 'Muska', 'Yüzük', 'Tılsım'],
};
DF.ITEM_PREFIX = [
  ['Eski', 'Paslı', 'Basit'],
  ['Sağlam', 'Çelik', 'Dövme'],
  ['Keskin', 'Kor', 'Buzul', 'Gölge'],
  ['Kadim', 'Lanetli', 'Şampiyon'],
  ['Ejder', 'Ölümsüz', 'Kıyamet'],
];
DF.BONUS_STATS = ['str', 'agi', 'int', 'vit', 'crit', 'hp'];
DF.STAT_NAMES = { atk: 'Saldırı', def: 'Savunma', hp: 'Can', mp: 'Mana', str: 'Güç', agi: 'Çeviklik', int: 'Zekâ', vit: 'Dayanıklılık', crit: 'Kritik %' };

// Arena kademeleri. offset: rakibin seviye farki. power: rakibin guc carpani.
DF.ARENAS = [
  { id: 'pit',   name: 'Acemi Çukuru',       desc: 'Isınmak için kolay rakipler.',        count: 1, offset: -1, power: 0.8,  ai: 0.35, reward: 0.7, minLevel: 1, loot: 0.3, rarity: 0, gear: 0 },
  { id: 'iron',  name: 'Demir Kapı',         desc: 'Dengeli bire bir düellolar.',         count: 1, offset: 0,  power: 1.0,  ai: 0.65, reward: 1.0, minLevel: 1, loot: 0.5, rarity: 1, gear: 0 },
  { id: 'duo',   name: 'İkiz Pençe',         desc: 'Tek başına iki rakibe karşı.',        count: 2, offset: -2, power: 0.72, ai: 0.65, reward: 1.5, minLevel: 3, loot: 0.6, rarity: 1, gear: 0 },
  { id: 'blood', name: 'Kan Meydanı',        desc: 'Senden güçlü, zeki gladyatörler.',    count: 1, offset: 1,  power: 0.88, ai: 0.9,  reward: 1.7, minLevel: 5, loot: 0.75, rarity: 2, gear: 1 },
  { id: 'champ', name: 'Şampiyonlar Salonu', desc: 'Dev şampiyon. Efsanevi ödül şansı.', count: 1, offset: 3,  power: 0.85, ai: 1.0,  reward: 3.0, minLevel: 8, loot: 1.0, rarity: 3, gear: 1, boss: true },
];

DF.MAX_LEVEL = 30;
DF.xpForLevel = l => Math.floor(60 * Math.pow(l, 1.55));

DF.ENEMY_NAMES = ['Varg', 'Krom', 'Selene', 'Thane', 'Morra', 'Dreth', 'Ilya', 'Korvan', 'Nyx', 'Bruk', 'Sable', 'Ashka', 'Oren', 'Vex', 'Ragna'];
DF.ENEMY_TITLES = ['Kül Yürüyen', 'Kemik Kıran', 'Sessiz', 'Kanlı', 'Son Nefes', 'Kor Dişli', 'Demir Yürek'];
