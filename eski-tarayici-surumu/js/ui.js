// Ekranlar: karakter olusturma, merkez, envanter, magaza, arena, savas arayuzu, sonuc.
(function () {
  const ui = () => document.getElementById('ui');
  const labels = () => document.getElementById('labels');
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const hex = n => '#' + n.toString(16).padStart(6, '0');
  const rarityName = it => `<span style="color:${DF.RARITY[it.rarity].color}">${esc(it.name)}</span>`;
  const statsLine = it => Object.keys(it.stats).map(k => `+${it.stats[k]} ${DF.STAT_NAMES[k]}`).join(' · ');

  let G; // main.js'in oyun nesnesi

  function renderCreate() {
    const st = { name: '', cls: 'warrior', look: { skin: DF.SKINS[0], hair: DF.HAIRS[0], cloth: DF.CLOTHS[0] } };
    const preview = () => DF.Gfx.showPreview(DF.newCharacter('', st.cls, st.look));
    const swatch = (key, list) => `<div class="swatches">${list.map(c =>
      `<button class="sw${st.look[key] === c ? ' on' : ''}" style="background:${hex(c)}" data-k="${key}" data-c="${c}" aria-label="Renk"></button>`).join('')}</div>`;
    const draw = () => {
      const typed = document.getElementById('nm');
      if (typed) st.name = typed.value;
      ui().innerHTML = `<div class="create panel">
        <div class="brand">KOR ARENA</div><div class="tagline">Küllerin içinden bir şampiyon doğuyor.</div>
        <label class="field" for="nm">Karakter adı</label>
        <input id="nm" type="text" maxlength="16" value="${esc(st.name)}" placeholder="Adını yaz">
        <span class="field">Sınıf</span>
        <div class="classes">${Object.keys(DF.CLASSES).map(k =>
          `<button class="cls${st.cls === k ? ' on' : ''}" data-cls="${k}">${DF.CLASSES[k].name}</button>`).join('')}</div>
        <div class="cdesc">${DF.CLASSES[st.cls].desc}</div>
        <span class="field">Ten</span>${swatch('skin', DF.SKINS)}
        <span class="field">Saç</span>${swatch('hair', DF.HAIRS)}
        <span class="field">Kıyafet</span>${swatch('cloth', DF.CLOTHS)}
        <p style="margin:18px 0 0"><button id="go" class="btn main">Arenaya Gir</button></p>
      </div>`;
      ui().querySelectorAll('[data-cls]').forEach(b => b.onclick = () => { st.cls = b.dataset.cls; draw(); preview(); });
      ui().querySelectorAll('[data-k]').forEach(b => b.onclick = () => { st.look[b.dataset.k] = +b.dataset.c; draw(); preview(); });
      document.getElementById('go').onclick = () => {
        const name = document.getElementById('nm').value.trim() || 'Adsız Şampiyon';
        G.create(name, st.cls, st.look);
      };
    };
    draw(); preview();
  }

  function renderHub(tab) {
    const ch = G.ch, s = DF.calcStats(ch), need = DF.xpForLevel(ch.level);
    const pct = ch.level >= DF.MAX_LEVEL ? 100 : Math.min(100, ch.xp / need * 100);
    DF.Gfx.showPreview(ch);
    ui().innerHTML = `
      <div class="topbar">
        <span class="who">${esc(ch.name)}</span><span>Sv. ${ch.level} ${DF.CLASSES[ch.cls].name}</span>
        <div class="xp" title="${ch.xp} / ${need} XP"><i style="width:${pct}%"></i></div>
        <span style="color:var(--mute)">${ch.wins} G · ${ch.losses} M</span>
        <span class="gold">◈ ${ch.gold}</span>
      </div>
      ${tab ? '' : `<div class="sheet panel">
        <div>Can <b>${s.maxHp}</b></div><div>Mana <b>${s.maxMp}</b></div><div>Saldırı <b>${s.atk}</b></div>
        <div>Savunma <b>${s.def}</b></div><div>Kritik <b>%${s.crit.toFixed(1)}</b></div><div>Saldırı hızı <b>${s.aspd.toFixed(2)}/sn</b></div>
        <div>Güç <b>${s.str}</b></div><div>Çeviklik <b>${s.agi}</b></div><div>Zekâ <b>${s.int}</b></div><div>Dayanıklılık <b>${s.vit}</b></div>
      </div>`}
      <div class="menu">
        <button class="btn main" data-tab="arena">Arena</button>
        <button class="btn" data-tab="inv">Envanter</button>
        <button class="btn" data-tab="shop">Mağaza</button>
        <button class="btn" data-tab="skills">Yetenekler</button>
        <button class="btn small" id="reset">Yeni karakter</button>
      </div>
      <div id="modal"></div>`;
    ui().querySelectorAll('[data-tab]').forEach(b => b.onclick = () => renderHub(tab === b.dataset.tab ? null : b.dataset.tab));
    document.getElementById('reset').onclick = () => {
      if (confirm('Mevcut karakterin silinecek. Emin misin?')) G.reset();
    };
    if (tab === 'arena') drawArena();
    if (tab === 'inv') drawInventory();
    if (tab === 'shop') drawShop();
    if (tab === 'skills') drawSkills();
  }

  const modal = (title, html, extra) => {
    document.getElementById('modal').innerHTML = `<div class="modal panel"><header><h2>${title}</h2>${extra || ''}</header>${html}</div>`;
  };

  function drawArena() {
    const ch = G.ch;
    modal('Arena', DF.ARENAS.map(a => {
      const lv = Math.max(1, ch.level + a.offset), open = ch.level >= a.minLevel;
      return `<div class="arena"><div><h3>${a.name}</h3>
        <p>${a.desc}<br>Rakip: ${a.count > 1 ? a.count + ' × ' : ''}Sv. ${lv}</p></div>
        <button class="btn" data-a="${a.id}" ${open ? '' : 'disabled'}>${open ? 'Savaş' : 'Sv. ' + a.minLevel + ' gerekli'}</button></div>`;
    }).join(''));
    document.querySelectorAll('[data-a]').forEach(b => b.onclick = () => G.fight(b.dataset.a));
  }

  function compare(it) {
    const cur = G.ch.equipped[it.slot];
    const keys = new Set([...Object.keys(it.stats), ...Object.keys(cur ? cur.stats : {})]);
    return [...keys].map(k => {
      const d = (it.stats[k] || 0) - ((cur && cur.stats[k]) || 0);
      return d ? `<span class="${d > 0 ? 'up' : 'down'}">${d > 0 ? '+' : ''}${d} ${DF.STAT_NAMES[k]}</span>` : '';
    }).filter(Boolean).join(' · ') || 'Fark yok';
  }
  const itemCard = (it, attr, sel) => `<button class="item${sel ? ' sel' : ''}" ${attr}>${rarityName(it)}<small>${DF.SLOTS[it.slot]} · Sv. ${it.level}</small></button>`;

  function drawInventory(sel) {
    const ch = G.ch;
    const slots = Object.keys(DF.SLOTS).map(k => {
      const it = ch.equipped[k];
      return it ? itemCard(it, `data-eq="${k}"`, sel && sel.uid === it.uid)
        : `<div class="item"><small>${DF.SLOTS[k]}</small><small>Boş</small></div>`;
    }).join('');
    const list = ch.inventory.map(it => itemCard(it, `data-it="${it.uid}"`, sel && sel.uid === it.uid)).join('') || '<small style="color:var(--mute)">Envanterin boş. Arenada kazanarak ganimet topla.</small>';
    let detail = '';
    if (sel) {
      const worn = ch.equipped[sel.slot] && ch.equipped[sel.slot].uid === sel.uid;
      detail = `<div class="detail">${rarityName(sel)} <small style="color:var(--mute)">${DF.RARITY[sel.rarity].name}</small><br>${statsLine(sel)}
        ${worn ? '' : `<br><small>Şu ankine göre: ${compare(sel)}</small>`}
        <div class="row">${worn ? `<button class="btn small" id="unq">Çıkar</button>`
          : `<button class="btn small" id="wear">Giy</button><button class="btn small" id="sell">Sat (◈ ${Math.round(sel.price * 0.4)})</button>`}</div></div>`;
    }
    modal(`Envanter (${ch.inventory.length}/${DF.INV_SIZE})`, `<div class="slots">${slots}</div><div class="grid">${list}</div>${detail}`);
    document.querySelectorAll('[data-eq]').forEach(b => b.onclick = () => drawInventory(ch.equipped[b.dataset.eq]));
    document.querySelectorAll('[data-it]').forEach(b => b.onclick = () => drawInventory(ch.inventory.find(i => i.uid == b.dataset.it)));
    const on = (id, fn) => { const b = document.getElementById(id); if (b) b.onclick = fn; };
    on('wear', () => { G.equip(sel); renderHub('inv'); });
    on('sell', () => { G.sell(sel); renderHub('inv'); });
    on('unq', () => { if (G.unequip(sel)) renderHub('inv'); });
  }

  function drawShop(sel) {
    const ch = G.ch, cost = 20 + ch.level * 10;
    let detail = '';
    if (sel) detail = `<div class="detail">${rarityName(sel)}<br>${statsLine(sel)}<br><small>Şu ankine göre: ${compare(sel)}</small>
      <div class="row"><button class="btn small" id="buy" ${ch.gold < sel.price || ch.inventory.length >= DF.INV_SIZE ? 'disabled' : ''}>Satın al (◈ ${sel.price})</button></div></div>`;
    modal('Mağaza', `<div class="grid">${ch.shop.map(it => itemCard(it, `data-s="${it.uid}"`, sel && sel.uid === it.uid).replace('</small>', ` · ◈ ${it.price}</small>`)).join('') || '<small>Raflar boş.</small>'}</div>${detail}`,
      `<button class="btn small" id="refresh" ${ch.gold < cost ? 'disabled' : ''}>Yenile (◈ ${cost})</button>`);
    document.querySelectorAll('[data-s]').forEach(b => b.onclick = () => drawShop(ch.shop.find(i => i.uid == b.dataset.s)));
    document.getElementById('refresh').onclick = () => { G.rerollShop(cost); renderHub('shop'); };
    const buy = document.getElementById('buy');
    if (buy) buy.onclick = () => { G.buy(sel); renderHub('shop'); };
  }

  function drawSkills() {
    const ch = G.ch;
    modal('Yetenekler', DF.CLASSES[ch.cls].skills.map(id => {
      const k = DF.SKILLS[id], open = ch.level >= k.unlock;
      return `<div class="skill${open ? '' : ' locked'}"><div class="ic">${k.icon}</div><div><b>${k.name}</b>
        <p>${k.desc} · ${k.cd} sn · ${k.mana} mana${open ? '' : ` · Sv. ${k.unlock}'de açılır`}</p></div></div>`;
    }).join(''));
  }

  // ---- Savas arayuzu ----
  let bars = {}, skillEls = [];
  function renderBattle(b, me) {
    const foes = b.ents.filter(e => e.team === 1);
    const fighter = (e, side) => `<div class="fighter"><h3>${esc(e.name)} · Sv. ${e.s.level}</h3>
      <div class="bar"><i id="hp${side}"></i></div><div class="bar mp"><i id="mp${side}"></i></div></div>`;
    ui().innerHTML = `
      <div class="hud-top">${fighter(me, 'A')}<div class="vs">VS</div>${fighter(foes[0], 'B')}</div>
      <div class="skillbar">${DF.CLASSES[me.cls].skills.map((id, i) => {
        const k = DF.SKILLS[id], open = me.skills.includes(id);
        return `<button class="sk${open ? '' : ' locked'}" data-sk="${id}" title="${k.name}: ${k.desc}"><span class="key">${i + 1}</span>${k.icon}<span class="cd"></span><span class="num"></span></button>`;
      }).join('')}</div>
      <div class="ctrl">
        <button class="btn small" id="auto">Oto yetenek</button>
        <button class="btn small" id="spd">Hız ×1</button>
        <button class="btn small" id="quit">Teslim ol</button>
      </div>
      <div class="hint">1-4: Yetenek · Sürükle: Kamera · Tekerlek: Yakınlaş<br>Rakibe tıkla: Hedef seç · Boşluk: Duraklat</div>`;
    labels().innerHTML = b.ents.filter(e => e.team === 1).map(e =>
      `<div class="lab" id="lab${e.id}">${esc(e.name)}<div class="bar"><i></i></div></div>`).join('');
    bars = { hpA: document.getElementById('hpA'), mpA: document.getElementById('mpA'), hpB: document.getElementById('hpB'), mpB: document.getElementById('mpB') };
    skillEls = [...ui().querySelectorAll('[data-sk]')].map(el => ({ el, id: el.dataset.sk, cd: el.querySelector('.cd'), num: el.querySelector('.num') }));
    skillEls.forEach(s => s.el.onclick = () => G.useSkill(s.id));
    document.getElementById('auto').onclick = e => { G.auto = !G.auto; e.target.classList.toggle('on', G.auto); };
    document.getElementById('auto').classList.toggle('on', G.auto);
    document.getElementById('spd').onclick = e => { G.speed = G.speed === 1 ? 2 : 1; e.target.textContent = 'Hız ×' + G.speed; };
    document.getElementById('spd').textContent = 'Hız ×' + G.speed;
    document.getElementById('quit').onclick = () => G.surrender();
  }

  function updateBattle(b, me) {
    const foe = b.ents.find(e => e.team === 1 && e === me.target) || b.ents.find(e => e.team === 1 && e.alive) || b.ents.find(e => e.team === 1);
    bars.hpA.style.width = me.hp / me.s.maxHp * 100 + '%';
    bars.mpA.style.width = me.mp / me.s.maxMp * 100 + '%';
    bars.hpB.style.width = foe.hp / foe.s.maxHp * 100 + '%';
    bars.mpB.style.width = foe.mp / foe.s.maxMp * 100 + '%';
    for (const s of skillEls) {
      const k = DF.SKILLS[s.id], cd = me.cds[s.id] || 0;
      s.cd.style.height = cd / k.cd * 100 + '%';
      s.num.textContent = cd > 0 ? Math.ceil(cd) : '';
      s.el.classList.toggle('off', me.mp < k.mana);
    }
    for (const e of b.ents) {
      if (e.team !== 1) continue;
      const el = document.getElementById('lab' + e.id);
      if (!el) continue;
      const p = DF.Gfx.project(e.x, e.ch.boss ? 3 : 2.3, e.z);
      el.style.display = e.alive && p.vis ? '' : 'none';
      el.style.left = p.x + 'px'; el.style.top = p.y + 'px';
      el.querySelector('i').style.width = e.hp / e.s.maxHp * 100 + '%';
    }
  }

  function floatText(ent, text, cls) {
    const p = DF.Gfx.project(ent.x + (Math.random() - 0.5) * 0.6, 2.1, ent.z);
    const d = document.createElement('div');
    d.className = 'dmg ' + (cls || ''); d.textContent = text;
    d.style.left = p.x + 'px'; d.style.top = p.y + 'px';
    labels().appendChild(d);
    setTimeout(() => d.remove(), 850);
  }

  function announce(text) {
    const d = document.createElement('div');
    d.className = 'announce'; d.textContent = text; ui().appendChild(d);
    setTimeout(() => d.remove(), 1000);
  }

  function renderResult(res, arena) {
    labels().innerHTML = '';
    const lootLine = res.loot ? `<p>Ganimet: ${rarityName(res.loot)}${res.lootSold ? ' (envanter dolu, satıldı)' : ''}</p><p><small>${statsLine(res.loot)}</small></p>` : '';
    ui().innerHTML = `<div class="result panel">
      <h1 class="${res.won ? '' : 'lose'}">${res.won ? 'ZAFER' : 'YENİLGİ'}</h1>
      <p>+${res.xp} XP${res.gold ? ` · ◈ +${res.gold}` : ''}</p>
      ${res.levels ? `<p class="lvlup">Seviye atladın! Sv. ${G.ch.level}</p>` : ''}
      ${lootLine}
      <div class="row"><button class="btn main" id="again">Tekrar Savaş</button><button class="btn" id="home">Merkeze Dön</button></div>
    </div>`;
    document.getElementById('again').onclick = () => G.fight(arena.id);
    document.getElementById('home').onclick = () => G.toHub();
  }

  DF.UI = {
    bind(g) { G = g; }, renderCreate, renderHub, renderBattle, updateBattle, floatText, announce, renderResult,
    clearLabels() { labels().innerHTML = ''; },
  };
})();
