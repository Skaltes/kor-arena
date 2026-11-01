// Oyunun akisi: kayit, ekran gecisleri, savas dongusu.
(function () {
  const KEY = 'korarena_save_v1';
  const G = {
    ch: null, battle: null, arena: null, me: null, brains: [], auto: false, speed: 1, paused: false, acc: 0, ending: 0,

    save() { try { localStorage.setItem(KEY, JSON.stringify(this.ch)); } catch (e) { /* gizli pencere: kayitsiz devam */ } },
    load() { try { return JSON.parse(localStorage.getItem(KEY)); } catch (e) { return null; } },

    create(name, cls, look) { this.ch = DF.newCharacter(name, cls, look); this.save(); DF.UI.renderHub('arena'); },
    reset() {
      try { localStorage.removeItem(KEY); } catch (e) { /* yok say */ }
      this.ch = null; DF.UI.renderCreate();
    },
    toHub() { DF.Gfx.clearBattle(); this.battle = null; DF.UI.clearLabels(); DF.UI.renderHub(); },

    equip(it) {
      const c = this.ch, i = c.inventory.indexOf(it);
      if (i < 0) return;
      const old = c.equipped[it.slot];
      c.inventory.splice(i, 1);
      if (old) c.inventory.push(old);
      c.equipped[it.slot] = it;
      this.save();
    },
    unequip(it) {
      const c = this.ch;
      if (it.slot === 'weapon' || c.inventory.length >= DF.INV_SIZE) return false; // silahsiz arena yok
      c.equipped[it.slot] = null; c.inventory.push(it); this.save();
      return true;
    },
    sell(it) {
      const c = this.ch, i = c.inventory.indexOf(it);
      if (i < 0) return;
      c.inventory.splice(i, 1); c.gold += Math.round(it.price * 0.4); this.save();
    },
    buy(it) {
      const c = this.ch, i = c.shop.indexOf(it);
      if (i < 0 || c.gold < it.price || c.inventory.length >= DF.INV_SIZE) return;
      c.gold -= it.price; c.shop.splice(i, 1); c.inventory.push(it); this.save();
    },
    rerollShop(cost) {
      if (this.ch.gold < cost) return;
      this.ch.gold -= cost; this.ch.shopSeed++; DF.refreshShop(this.ch); this.save();
    },

    fight(id) {
      const a = DF.ARENAS.find(x => x.id === id), c = this.ch;
      const seed = (Math.random() * 1e9) | 0, rng = DF.makeRng(seed);
      const foes = [];
      for (let i = 0; i < a.count; i++) {
        const opp = DF.makeOpponent(c.level + a.offset, a, rng);
        foes.push({ ch: opp, stats: DF.calcStats(opp, a.power) });
      }
      const b = new DF.Battle([[{ ch: c, stats: DF.calcStats(c) }], foes], seed);
      this.battle = b; this.arena = a; this.me = b.ents[0]; this.acc = 0; this.ending = 0; this.paused = false;
      this.rewardRng = rng;
      this.brains = b.ents.filter(e => e.team === 1).map(e => new DF.Brain(e, a.ai, rng));
      this.myBrain = new DF.Brain(this.me, 1, rng);
      DF.Gfx.startBattle(b);
      DF.UI.renderBattle(b, this.me);
      DF.UI.announce('SAVAŞ!');
    },
    useSkill(id) {
      if (this.battle && !this.battle.over) this.battle.command({ ent: this.me.id, type: 'skill', skill: id });
    },
    surrender() {
      if (!this.battle || this.battle.over) return;
      this.battle.over = true; this.battle.winner = 1; this.finish();
    },
    finish() {
      const b = this.battle;
      const res = DF.grantReward(this.ch, this.arena, b.ents.filter(e => e.team === 1).map(e => e.s.level), b.winner === 0, this.rewardRng);
      this.save();
      DF.UI.renderResult(res, this.arena);
    },

    drainEvents() {
      const b = this.battle;
      for (const ev of b.events.splice(0)) {
        DF.Gfx.onEvent(ev, b);
        if (ev.t === 'hit') {
          const e = b.ents[ev.ent];
          DF.UI.floatText(e, ev.absorbed ? 'Emildi' : ev.dmg, ev.absorbed ? 'heal' : ev.crit ? 'crit' : ev.dot ? 'dot' : '');
          if (e.id === this.me.target?.id) DF.Gfx.markTarget(e);
        }
        if (ev.t === 'miss') DF.UI.floatText(b.ents[ev.ent], 'Kaçtı', 'miss');
        if (ev.t === 'end') { this.ending = 1.6; DF.UI.announce(ev.winner === 0 ? 'ZAFER!' : 'YENİLDİN'); }
      }
    },

    frame(dt) {
      const b = this.battle;
      if (b) {
        if (!this.paused && !b.over) {
          this.acc += dt * this.speed;
          while (this.acc >= DF.SIM_STEP) {
            this.acc -= DF.SIM_STEP;
            this.brains.forEach(br => br.update(b, DF.SIM_STEP));
            if (this.auto) this.myBrain.update(b, DF.SIM_STEP);
            b.tick();
          }
        }
        this.drainEvents();
        if (!b.over || this.ending > 0) DF.UI.updateBattle(b, this.me);
        if (this.ending > 0) {
          this.ending -= dt;
          if (this.ending <= 0) this.finish();
        }
      }
      DF.Gfx.render();
    },
  };
  DF.game = G;

  addEventListener('load', () => {
    DF.UI.bind(G);
    const canvas = document.getElementById('view');
    DF.Gfx.init(canvas);
    canvas.addEventListener('click', e => {
      if (!G.battle || G.battle.over) return;
      const t = DF.Gfx.pickEnt(e.clientX, e.clientY);
      if (t) { G.battle.command({ ent: G.me.id, type: 'target', target: t.id }); DF.Gfx.markTarget(t); }
    });
    addEventListener('keydown', e => {
      if (!G.battle || G.battle.over) return;
      const skills = DF.CLASSES[G.me.cls].skills, n = +e.key;
      if (n >= 1 && n <= 4) G.useSkill(skills[n - 1]);
      if (e.code === 'Space') { e.preventDefault(); G.paused = !G.paused; DF.UI.announce(G.paused ? 'DURAKLATILDI' : 'DEVAM'); }
    });
    G.ch = G.load();
    if (G.ch) DF.UI.renderHub(); else DF.UI.renderCreate();
    let last = performance.now();
    (function loop(now) {
      const dt = Math.min(0.1, (now - last) / 1000); last = now;
      G.frame(dt);
      requestAnimationFrame(loop);
    })(last);
  });
})();
