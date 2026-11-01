// Savas motoru. Ekrani bilmez: girdi = komutlar, cikti = olaylar (events).
// Oyuncu da yapay zeka da yalnizca komut gonderir; PvP'de komutlar agdan gelecek.
(function () {
  const STEP = 1 / 30, ARENA_R = 11.5;
  const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

  class Battle {
    constructor(teams, seed) { // teams: [[{ch, stats}], [...]]
      this.rng = DF.makeRng(seed);
      this.t = 0; this.ents = []; this.projs = []; this.delayed = [];
      this.events = []; this.cmds = []; this.over = false; this.winner = -1;
      teams.forEach((team, ti) => team.forEach((m, i) => {
        const offs = (i - (team.length - 1) / 2) * 3;
        const s = m.stats;
        this.ents.push({
          id: this.ents.length, team: ti, ch: m.ch, s, name: m.ch.name, cls: m.ch.cls,
          x: offs, z: ti === 0 ? 5 : -5, face: ti === 0 ? Math.PI : 0, moving: false,
          hp: s.maxHp, mp: s.maxMp, shield: 0, shieldT: 0, target: null, swing: 0, atkT: 0.4 + i * 0.3,
          cds: {}, fx: [], lock: 0, alive: true,
        });
      }));
      for (const e of this.ents) e.skills = DF.CLASSES[e.cls].skills.filter(id => DF.SKILLS[id].unlock <= e.s.level);
    }

    command(c) { this.cmds.push(c); } // {ent, type:'skill'|'target', skill, target}

    enemiesOf(e) { return this.ents.filter(o => o.alive && o.team !== e.team); }
    getFx(e, type) { return e.fx.find(f => f.type === type); }

    canCast(e, id) {
      const sk = DF.SKILLS[id];
      if (!e.alive || !e.skills.includes(id) || e.lock > 0 || this.getFx(e, 'stun')) return false;
      if ((e.cds[id] || 0) > 0 || e.mp < sk.mana) return false;
      if (sk.kind === 'self' || sk.kind === 'aoe_self') return true;
      return !!e.target && e.target.alive && dist(e, e.target) <= sk.range;
    }

    tick() {
      if (this.over) return;
      this.t += STEP;
      for (const c of this.cmds.splice(0)) this.applyCommand(c);
      for (const e of this.ents) if (e.alive) this.tickEnt(e);
      this.tickProjectiles();
      for (const d of this.delayed) d.t -= STEP;
      for (const d of this.delayed.filter(d => d.t <= 0)) this.resolveAoe(d.src, d.sk, d.x, d.z);
      this.delayed = this.delayed.filter(d => d.t > 0);
      this.checkEnd();
    }

    applyCommand(c) {
      const e = this.ents[c.ent];
      if (!e || !e.alive) return;
      if (c.type === 'target') {
        const t = this.ents[c.target];
        if (t && t.alive && t.team !== e.team) e.target = t;
      } else if (c.type === 'skill' && this.canCast(e, c.skill)) this.cast(e, c.skill);
    }

    tickEnt(e) {
      for (const id in e.cds) e.cds[id] = Math.max(0, e.cds[id] - STEP);
      e.mp = Math.min(e.s.maxMp, e.mp + e.s.mpRegen * STEP);
      e.lock = Math.max(0, e.lock - STEP);
      if (e.shieldT > 0) { e.shieldT -= STEP; if (e.shieldT <= 0) e.shield = 0; }

      for (const f of e.fx) {
        f.t -= STEP;
        if (f.type === 'dot') {
          f.tick -= STEP;
          if (f.tick <= 0) { f.tick = 1; this.damage(f.src, e, f.dps, { dot: true, noDodge: true }); }
        }
      }
      e.fx = e.fx.filter(f => f.t > 0);
      if (!e.alive) return;

      e.moving = false;
      if (e.swing > 0) { // vurus ani geciktirilir ki animasyonla ayni kareye gelsin
        e.swing -= STEP;
        if (e.swing <= 0 && e.target && e.target.alive) this.landBasic(e);
      }
      if (this.getFx(e, 'stun')) return;
      if (!e.target || !e.target.alive) {
        let best = null, bd = 1e9;
        for (const o of this.enemiesOf(e)) { const d = dist(e, o); if (d < bd) { bd = d; best = o; } }
        e.target = best;
      }
      const t = e.target;
      if (!t) return;
      e.face = Math.atan2(t.x - e.x, t.z - e.z);
      e.atkT -= STEP;
      if (e.lock > 0) return;
      const d = dist(e, t), reach = e.s.range;
      if (d > reach) {
        const slow = this.getFx(e, 'slow');
        const v = e.s.speed * (slow ? 1 - slow.pct : 1) * STEP;
        const step = Math.min(v, d - reach + 0.05);
        e.x += Math.sin(e.face) * step; e.z += Math.cos(e.face) * step;
        e.moving = true;
        const r = Math.hypot(e.x, e.z);
        if (r > ARENA_R) { e.x *= ARENA_R / r; e.z *= ARENA_R / r; }
      } else if (e.atkT <= 0 && e.swing <= 0) {
        e.atkT = 1 / e.s.aspd;
        e.swing = 0.28;
        this.events.push({ t: 'attack', ent: e.id });
      }
    }

    landBasic(e) {
      const t = e.target;
      if (e.s.ranged) {
        this.projs.push({ src: e, dst: t, x: e.x, z: e.z, speed: 16, sk: null, mult: 1, fx: 'bolt' });
        this.events.push({ t: 'proj', idx: this.projs[this.projs.length - 1], fx: 'bolt' });
      } else if (dist(e, t) <= e.s.range * 1.5) {
        this.hit(e, t, 1, { basic: true });
      }
    }

    atkOf(e) {
      let a = e.s.atk;
      for (const f of e.fx) if (f.type === 'buff' && f.atk) a *= 1 + f.atk;
      return a;
    }
    defOf(e) {
      let d = e.s.def;
      for (const f of e.fx) if (f.type === 'buff' && f.def) d *= 1 + f.def;
      return d;
    }

    hit(src, dst, mult, opt) {
      opt = opt || {};
      const r = this.rng;
      const dodgeBuff = dst.fx.find(f => f.type === 'buff' && f.dodge);
      if (dodgeBuff || (opt.basic && r() * 100 < dst.s.dodge)) {
        this.events.push({ t: 'miss', ent: dst.id });
        return false;
      }
      const crit = opt.forceCrit || r() * 100 < src.s.crit;
      let dmg = this.atkOf(src) * mult * (0.92 + r() * 0.16) * (crit ? 1.75 : 1);
      const def = this.defOf(dst);
      dmg *= 1 - def / (def + 40 + dst.s.level * 6);
      this.damage(src, dst, dmg, { crit, skill: opt.skill });
      return true;
    }

    damage(src, dst, amount, opt) {
      if (!dst.alive) return;
      let d = Math.max(1, Math.round(amount));
      const shown = d;
      if (dst.shield > 0) {
        const ab = Math.min(dst.shield, d);
        dst.shield -= ab; d -= ab;
      }
      dst.hp -= d;
      this.events.push({ t: 'hit', ent: dst.id, src: src.id, dmg: shown, crit: !!opt.crit, dot: !!opt.dot, absorbed: d === 0 });
      if (dst.hp <= 0) {
        dst.hp = 0; dst.alive = false; dst.moving = false;
        this.events.push({ t: 'death', ent: dst.id });
      }
    }

    cast(e, id) {
      const sk = DF.SKILLS[id], t = e.target;
      e.mp -= sk.mana; e.cds[id] = sk.cd; e.lock = 0.35; e.swing = 0;
      this.events.push({ t: 'cast', ent: e.id, skill: id });
      if (sk.kind === 'melee') {
        if (this.hit(e, t, sk.mult, { forceCrit: sk.forceCrit, skill: id })) this.applyRiders(e, t, sk);
      } else if (sk.kind === 'proj') {
        const p = { src: e, dst: t, x: e.x, z: e.z, speed: sk.speed, sk, mult: sk.mult, fx: sk.fx };
        this.projs.push(p);
        this.events.push({ t: 'proj', idx: p, fx: sk.fx });
      } else if (sk.kind === 'aoe_self') {
        this.resolveAoe(e, sk, e.x, e.z);
      } else if (sk.kind === 'aoe_ground') {
        this.delayed.push({ t: sk.delay, src: e, sk, x: t.x, z: t.z });
        this.events.push({ t: 'telegraph', x: t.x, z: t.z, r: sk.radius, dur: sk.delay, skill: id });
      } else if (sk.kind === 'dash') {
        const a = t.face + Math.PI;
        e.x = t.x + Math.sin(a) * 1.3; e.z = t.z + Math.cos(a) * 1.3;
        e.face = Math.atan2(t.x - e.x, t.z - e.z);
        this.events.push({ t: 'blink', ent: e.id });
        this.hit(e, t, sk.mult, { skill: id });
      } else if (sk.kind === 'self') {
        if (sk.buff) e.fx.push(Object.assign({ type: 'buff', t: sk.buff.dur }, sk.buff));
        if (sk.shield) { e.shield = e.s.atk * sk.shield; e.shieldT = sk.dur; }
      }
    }

    applyRiders(src, t, sk) {
      if (sk.stun) { t.fx.push({ type: 'stun', t: sk.stun }); t.swing = 0; }
      if (sk.slow) t.fx.push({ type: 'slow', t: sk.slow.dur, pct: sk.slow.pct });
      if (sk.dot) t.fx.push({ type: 'dot', t: sk.dot.dur, src, tick: 1, dps: this.atkOf(src) * sk.dot.mult });
    }

    resolveAoe(src, sk, x, z) {
      this.events.push({ t: 'aoe', x, z, r: sk.radius, skill: Object.keys(DF.SKILLS).find(k => DF.SKILLS[k] === sk) });
      for (const o of this.enemiesOf(src)) {
        if (Math.hypot(o.x - x, o.z - z) <= sk.radius && this.hit(src, o, sk.mult, {})) this.applyRiders(src, o, sk);
      }
    }

    tickProjectiles() {
      for (const p of this.projs) {
        const dx = p.dst.x - p.x, dz = p.dst.z - p.z, d = Math.hypot(dx, dz), v = p.speed * STEP;
        if (d <= v + 0.3) {
          p.done = true;
          if (p.dst.alive) this.hit(p.src, p.dst, p.mult, { basic: !p.sk, skill: p.sk && p.sk.name });
        } else { p.x += dx / d * v; p.z += dz / d * v; }
      }
      this.projs = this.projs.filter(p => !p.done);
    }

    checkEnd() {
      const a = this.ents.some(e => e.alive && e.team === 0), b = this.ents.some(e => e.alive && e.team === 1);
      if (a && b) return;
      this.over = true; this.winner = a ? 0 : 1;
      this.events.push({ t: 'end', winner: this.winner });
    }
  }

  // Yapay zeka: oyuncuyla ayni komutlari gonderir. skill 0-1 arasi "zeka": tepki sikligi ve dogru secim.
  class Brain {
    constructor(ent, skill, rng) { this.e = ent; this.skill = skill; this.rng = rng; this.wait = 0.8; }
    update(b, dt) {
      this.wait -= dt;
      if (this.wait > 0) return;
      this.wait = 0.25 + (1 - this.skill) * 0.9;
      const e = this.e;
      if (!e.alive) return;
      for (const id of e.skills.slice().reverse()) {
        if (!b.canCast(e, id)) continue;
        if (this.rng() > 0.4 + this.skill * 0.6) continue;
        if (this.good(b, id)) { b.command({ ent: e.id, type: 'skill', skill: id }); return; }
      }
    }
    good(b, id) {
      const e = this.e, sk = DF.SKILLS[id], foes = b.enemiesOf(e);
      const near = foes.filter(o => dist(e, o) <= (sk.radius || 3)).length;
      if (sk.kind === 'aoe_self') return near > 0;
      if (sk.buff && sk.buff.dodge) return e.hp / e.s.maxHp < 0.6;
      if (sk.shield) return e.hp / e.s.maxHp < 0.75 && e.shield <= 0;
      if (sk.stun) return !b.getFx(e.target, 'stun');
      if (sk.dot) return !b.getFx(e.target, 'dot');
      return true;
    }
  }

  DF.Battle = Battle; DF.Brain = Brain; DF.SIM_STEP = STEP;
})();
