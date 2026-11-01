// Karakter kurallari: tohumlu rastgele sayi, stat hesabi, esya ve rakip uretimi.
// Ekrandan bagimsizdir; PvP'de sunucu ayni dosyayi kullanabilir.
(function () {
  DF.makeRng = function (seed) {
    let s = seed >>> 0 || 1;
    return function () { // mulberry32
      s = (s + 0x6D2B79F5) >>> 0;
      let t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  };
  const pick = (rng, a) => a[Math.floor(rng() * a.length)];
  let uid = Date.now() % 1000000;

  // Karakterin son degerleri: sinif + seviye + ekipman. Savas buradan baslar.
  DF.calcStats = function (ch, powerMult) {
    const c = DF.CLASSES[ch.cls], L = ch.level, p = powerMult || 1;
    const prim = {};
    for (const k in c.base) prim[k] = c.base[k] + c.grow[k] * (L - 1);
    const sum = { atk: 0, def: 0, hp: 0, mp: 0, crit: 0 };
    for (const slot in ch.equipped) {
      const it = ch.equipped[slot];
      if (!it) continue;
      for (const k in it.stats) {
        if (k in prim) prim[k] += it.stats[k]; else sum[k] = (sum[k] || 0) + it.stats[k];
      }
    }
    const atk = (6 + prim[c.main] * 1.6 + sum.atk) * p;
    const s = {
      str: Math.round(prim.str), agi: Math.round(prim.agi), int: Math.round(prim.int), vit: Math.round(prim.vit),
      maxHp: Math.round((120 + prim.vit * 15 + L * 8 + sum.hp) * p * 3.2),
      maxMp: Math.round(60 + prim.int * 4 + L * 3 + sum.mp),
      mpRegen: 4 + prim.int * 0.06,
      atk: Math.round(atk),
      def: Math.round((prim.vit * 0.5 + sum.def) * p),
      crit: Math.min(60, 5 + prim.agi * 0.3 + sum.crit),
      dodge: Math.min(25, prim.agi * 0.25),
      aspd: c.aspd * Math.min(1.8, 1 + prim.agi * 0.006),
      speed: c.speed, range: c.range, ranged: !!c.ranged, level: L,
    };
    return s;
  };

  DF.itemBudget = (level, rarity) => (4 + level * 2.2) * DF.RARITY[rarity].mult;

  DF.makeItem = function (slot, level, rarity, cls, rng) {
    rng = rng || Math.random;
    const R = DF.RARITY[rarity], b = DF.itemBudget(level, rarity), stats = {};
    let type = slot;
    if (slot === 'weapon') { type = pick(rng, DF.CLASSES[cls].weapons); stats.atk = Math.round(b * 1.1); }
    if (slot === 'armor') { stats.def = Math.round(b * 1.0); stats.hp = Math.round(b * 2.5); }
    if (slot === 'helmet') { stats.def = Math.round(b * 0.55); stats.hp = Math.round(b * 1.2); }
    if (slot === 'accessory') { stats.crit = Math.round(1 + rarity * 1.2); stats.mp = Math.round(b * 1.5); }
    for (let i = 0; i < R.bonus; i++) {
      const k = pick(rng, DF.BONUS_STATS);
      const v = k === 'crit' ? 1 + rarity : k === 'hp' ? Math.round(b * 1.5) : Math.max(1, Math.round(b * 0.28));
      stats[k] = (stats[k] || 0) + v;
    }
    const base = pick(rng, DF.ITEM_BASES[type]);
    return {
      uid: ++uid, slot, type, rarity, level, cls: slot === 'weapon' ? cls : null,
      name: pick(rng, DF.ITEM_PREFIX[rarity]) + ' ' + base, stats,
      price: Math.round(b * 5 * R.price),
      look: { tier: Math.min(4, rarity + (level >= 15 ? 1 : 0)), variant: Math.floor(rng() * 4) },
    };
  };

  DF.newCharacter = function (name, cls, look) {
    const ch = {
      v: 1, name, cls, look, level: 1, xp: 0, gold: 120, wins: 0, losses: 0,
      equipped: { weapon: null, helmet: null, armor: null, accessory: null }, inventory: [],
      shop: [], shopSeed: 1,
    };
    ch.equipped.weapon = DF.makeItem('weapon', 1, 0, cls);
    ch.equipped.armor = DF.makeItem('armor', 1, 0, cls);
    DF.refreshShop(ch);
    return ch;
  };

  DF.refreshShop = function (ch) {
    const rng = DF.makeRng(ch.shopSeed * 7919 + ch.level * 31);
    const items = [];
    for (let i = 0; i < 8; i++) {
      const roll = rng();
      const rarity = roll < 0.45 ? 0 : roll < 0.8 ? 1 : roll < 0.96 ? 2 : 3;
      const slot = pick(rng, ['weapon', 'weapon', 'armor', 'helmet', 'accessory']);
      const lv = Math.max(1, ch.level + Math.floor(rng() * 3) - 1);
      items.push(DF.makeItem(slot, lv, rarity, ch.cls, rng));
    }
    ch.shop = items;
  };

  // Rakip, oyuncuyla ayni bicimde bir karakterdir: PvP'de buraya gercek oyuncunun kopyasi gelir.
  DF.makeOpponent = function (level, arena, rng) {
    const cls = pick(rng, Object.keys(DF.CLASSES));
    const L = Math.max(1, Math.min(DF.MAX_LEVEL + 5, level));
    const look = {
      skin: pick(rng, DF.SKINS), hair: pick(rng, DF.HAIRS),
      cloth: pick(rng, DF.CLOTHS),
    };
    const ch = {
      name: pick(rng, DF.ENEMY_NAMES) + ' ' + pick(rng, DF.ENEMY_TITLES), cls, look, level: L,
      equipped: { weapon: null, helmet: null, armor: null, accessory: null }, boss: !!arena.boss,
    };
    for (const slot in ch.equipped) {
      const r = Math.min(4, Math.max(0, arena.gear + (rng() < 0.2 ? 1 : 0) - (slot === 'accessory' ? 1 : 0)));
      if (slot === 'helmet' && arena.gear === 0 && rng() < 0.5) continue;
      ch.equipped[slot] = DF.makeItem(slot, L, r, cls, rng);
    }
    return ch;
  };

  DF.grantReward = function (ch, arena, oppLevels, won, rng) {
    const lv = oppLevels.reduce((a, b) => a + b, 0) / oppLevels.length;
    const res = { xp: 0, gold: 0, levels: 0, loot: null, won };
    const base = (30 + 12 * lv) * arena.reward * oppLevels.length ** 0.5;
    res.xp = Math.round(won ? base : base * 0.2);
    res.gold = won ? Math.round((22 + 9 * lv) * arena.reward * (0.9 + rng() * 0.2)) : 0;
    ch.gold += res.gold;
    if (won) ch.wins++; else ch.losses++;
    if (ch.level < DF.MAX_LEVEL) ch.xp += res.xp;
    while (ch.level < DF.MAX_LEVEL && ch.xp >= DF.xpForLevel(ch.level)) {
      ch.xp -= DF.xpForLevel(ch.level);
      ch.level++; res.levels++;
    }
    if (won && rng() < arena.loot) {
      const r = Math.min(4, arena.rarity + (rng() < 0.25 ? 1 : 0) + (rng() < 0.05 ? 1 : 0));
      res.loot = DF.makeItem(pick(rng, Object.keys(DF.SLOTS)), ch.level, r, ch.cls, rng);
      if (ch.inventory.length < DF.INV_SIZE) ch.inventory.push(res.loot);
      else { ch.gold += Math.round(res.loot.price * 0.4); res.lootSold = true; }
    }
    if (res.levels) { ch.shopSeed++; DF.refreshShop(ch); }
    return res;
  };

  DF.INV_SIZE = 24;
  DF.SKINS = [0xf1c9a5, 0xd9a47c, 0xa8704a, 0x6d4630, 0xcfd6dd];
  DF.HAIRS = [0x2a1d14, 0x6b3a1e, 0xc9a24a, 0xd9dde2, 0xa32222, 0x2d3f8a];
  DF.CLOTHS = [0xb5482e, 0x3e7a5e, 0x4a57b8, 0x7c3a9a, 0xb8902f, 0x2f3238];
})();
