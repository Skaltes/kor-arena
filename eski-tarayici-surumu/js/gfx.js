// 3D gorunum: arena, karakterler, efektler. Oyun kurallarini bilmez, sadece sim'in durumunu cizer.
(function () {
  const T = THREE;
  const METAL = [0x85817a, 0xb4bcc4, 0x6fa8e0, 0xa86be0, 0xf0a030];
  let renderer, scene, camera, clock, sparkTex;
  const cam = { yaw: 0, pitch: 0.55, dist: 15, tx: 0, ty: 1, tz: 0, mode: 'hub', spin: 0 };
  let views = [], preview = null, sprites = [], rings = [], shots = [], flames = [], torchLights = [];
  let crowd, crowdData = [], cheer = 0, embers;

  function canvasTex(size, draw, repeat) {
    const c = document.createElement('canvas'); c.width = c.height = size;
    draw(c.getContext('2d'), size);
    const t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace;
    t.wrapS = t.wrapT = T.RepeatWrapping; t.anisotropy = 8;
    if (repeat) t.repeat.set(repeat, repeat);
    return t;
  }
  function stoneTex(ctx, s) {
    ctx.fillStyle = '#5b5148'; ctx.fillRect(0, 0, s, s);
    const n = 8, b = s / n;
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      const v = 70 + Math.random() * 34 | 0, ox = y % 2 ? b / 2 : 0;
      ctx.fillStyle = `rgb(${v + 8},${v},${v - 8})`;
      ctx.fillRect(x * b + ox + 2, y * b + 2, b - 4, b - 4);
      ctx.fillRect(x * b + ox + 2 - s, y * b + 2, b - 4, b - 4);
    }
    for (let i = 0; i < 2500; i++) {
      ctx.fillStyle = `rgba(${Math.random() < 0.5 ? '0,0,0' : '255,240,220'},${Math.random() * 0.1})`;
      ctx.fillRect(Math.random() * s, Math.random() * s, 2 + Math.random() * 5, 2 + Math.random() * 5);
    }
  }

  function buildArena() {
    const floorTex = canvasTex(512, stoneTex, 5);
    const floor = new T.Mesh(new T.CircleGeometry(13, 64), new T.MeshStandardMaterial({ map: floorTex, roughness: 0.92 }));
    floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; scene.add(floor);

    const runeMat = new T.MeshStandardMaterial({ color: 0x2a0d05, emissive: 0xff5a1e, emissiveIntensity: 1.5 });
    [[11.9, 12.05], [6, 6.08], [2.4, 2.48]].forEach(r => {
      const m = new T.Mesh(new T.RingGeometry(r[0], r[1], 72), runeMat);
      m.rotation.x = -Math.PI / 2; m.position.y = 0.012; scene.add(m);
    });
    for (let i = 0; i < 12; i++) {
      const a = i / 12 * Math.PI * 2;
      const m = new T.Mesh(new T.BoxGeometry(0.1, 0.01, 0.55), runeMat);
      m.position.set(Math.sin(a) * 9.5, 0.012, Math.cos(a) * 9.5); m.rotation.y = a; scene.add(m);
    }

    const wallTex = canvasTex(512, stoneTex); wallTex.repeat.set(10, 1);
    const wallMat = new T.MeshStandardMaterial({ map: wallTex, roughness: 0.95, side: T.DoubleSide });
    const wall = new T.Mesh(new T.CylinderGeometry(13.3, 13.3, 1.7, 64, 1, true), wallMat);
    wall.position.y = 0.85; wall.receiveShadow = true; scene.add(wall);

    for (let i = 0; i < 5; i++) { // tribun basamaklari
      const r = 13.6 + i * 1.5, h = 1.9 + i * 1.05;
      const ring = new T.Mesh(new T.CylinderGeometry(r + 1.5, r + 1.5, 1.05, 64, 1, true), new T.MeshStandardMaterial({ color: 0x2c2522, roughness: 1, side: T.DoubleSide }));
      ring.position.y = h; scene.add(ring);
      const top = new T.Mesh(new T.RingGeometry(r, r + 1.55, 64), new T.MeshStandardMaterial({ color: 0x38302b, roughness: 1, side: T.DoubleSide }));
      top.rotation.x = -Math.PI / 2; top.position.y = h + 0.52; scene.add(top);
    }

    const COUNT = 420;
    crowd = new T.InstancedMesh(new T.CapsuleGeometry(0.3, 0.5, 3, 6), new T.MeshStandardMaterial({ roughness: 0.9 }), COUNT);
    const col = new T.Color(), m4 = new T.Matrix4();
    const tones = [0x7c3a2c, 0x3b4a6b, 0x6b5a2a, 0x4a2f55, 0x38563f, 0x8d8378];
    for (let i = 0; i < COUNT; i++) {
      const row = Math.floor(Math.random() * 5), a = Math.random() * Math.PI * 2, r = 14.3 + row * 1.5 + Math.random() * 0.4;
      const d = { x: Math.sin(a) * r, y: 2.9 + row * 1.05, z: Math.cos(a) * r, ph: Math.random() * 6.28 };
      crowdData.push(d);
      m4.setPosition(d.x, d.y, d.z); crowd.setMatrixAt(i, m4);
      crowd.setColorAt(i, col.setHex(tones[i % tones.length]));
    }
    crowd.frustumCulled = false; scene.add(crowd);

    const pillarMat = new T.MeshStandardMaterial({ map: canvasTex(256, stoneTex), roughness: 0.9 });
    const bowlMat = new T.MeshStandardMaterial({ color: 0x241a14, metalness: 0.7, roughness: 0.4 });
    for (let i = 0; i < 8; i++) {
      const a = (i + 0.5) / 8 * Math.PI * 2, x = Math.sin(a) * 13.3, z = Math.cos(a) * 13.3;
      const p = new T.Mesh(new T.CylinderGeometry(0.5, 0.65, 5.6, 8), pillarMat);
      p.position.set(x, 2.8, z); p.castShadow = true; scene.add(p);
      const bowl = new T.Mesh(new T.CylinderGeometry(0.7, 0.35, 0.4, 10), bowlMat);
      bowl.position.set(x, 5.75, z); scene.add(bowl);
      const flame = new T.Sprite(new T.SpriteMaterial({ map: sparkTex, color: 0xff8a2a, blending: T.AdditiveBlending, depthWrite: false }));
      flame.position.set(x, 6.3, z); flame.scale.set(1.8, 2.6, 1); flame.userData.ph = i * 1.7;
      scene.add(flame); flames.push(flame);
      if (i % 2 === 0) {
        const l = new T.PointLight(0xff8a3c, 60, 26, 1.8);
        l.position.set(x * 0.9, 6, z * 0.9); scene.add(l); torchLights.push(l);
      }
    }

    const geo = new T.BufferGeometry(), N = 90, pos = new Float32Array(N * 3);
    for (let i = 0; i < N; i++) { pos[i * 3] = (Math.random() - 0.5) * 24; pos[i * 3 + 1] = Math.random() * 10; pos[i * 3 + 2] = (Math.random() - 0.5) * 24; }
    geo.setAttribute('position', new T.BufferAttribute(pos, 3));
    embers = new T.Points(geo, new T.PointsMaterial({ color: 0xff8a3c, size: 0.09, blending: T.AdditiveBlending, transparent: true, depthWrite: false }));
    scene.add(embers);
  }

  // ---- Karakter ----
  function mat(color, opt) { return new T.MeshStandardMaterial(Object.assign({ color, roughness: 0.65 }, opt)); }
  function part(geo, material, parent, x, y, z) {
    const m = new T.Mesh(geo, material); m.position.set(x || 0, y || 0, z || 0); m.castShadow = true;
    parent.add(m); return m;
  }

  function buildWeapon(it, hand, mats) {
    if (!it) return;
    const tier = it.look.tier, c = METAL[it.rarity];
    const glow = it.rarity >= 3 ? { emissive: c, emissiveIntensity: 0.7 } : {};
    const blade = mat(c, Object.assign({ metalness: 0.85, roughness: 0.3 }, glow)), grip = mat(0x3a2517); mats.push(blade, grip);
    const g = new T.Group(); hand.add(g); g.rotation.x = Math.PI / 2;
    if (it.type === 'sword') {
      const L = 0.95 + tier * 0.06;
      part(new T.BoxGeometry(0.1, L, 0.03), blade, g, 0, L / 2 + 0.14, 0);
      part(new T.BoxGeometry(0.34 + tier * 0.03, 0.05, 0.08), blade, g, 0, 0.13, 0);
      part(new T.CylinderGeometry(0.03, 0.03, 0.26), grip, g, 0, 0, 0);
    } else if (it.type === 'axe') {
      part(new T.CylinderGeometry(0.035, 0.035, 1.15), grip, g, 0, 0.35, 0);
      const S = new T.Shape(), r = 0.3 + tier * 0.025;
      S.moveTo(0, 0.09); S.quadraticCurveTo(r * 0.7, 0.14, r, r * 1.05);
      S.quadraticCurveTo(r * 0.72, 0, r, -r * 1.05); S.quadraticCurveTo(r * 0.7, -0.14, 0, -0.09); S.closePath();
      part(new T.ExtrudeGeometry(S, { depth: 0.035, bevelEnabled: false }), blade, g, 0.02, 0.8, -0.018);
    } else if (it.type === 'dagger') {
      part(new T.ConeGeometry(0.06, 0.55, 4), blade, g, 0, 0.36, 0);
      part(new T.BoxGeometry(0.17, 0.03, 0.05), blade, g, 0, 0.09, 0);
      part(new T.CylinderGeometry(0.025, 0.025, 0.16), grip, g, 0, 0, 0);
    } else {
      part(new T.CylinderGeometry(0.03, 0.045, 1.8), grip, g, 0, 0.45, 0);
      const orbC = [0x6a8dff, 0x7dffb4, 0x66c8ff, 0xc77dff, 0xffaa33][it.rarity];
      const orb = mat(orbC, { emissive: orbC, emissiveIntensity: 1.6 }); mats.push(orb);
      part(new T.IcosahedronGeometry(0.13 + tier * 0.02, 0), orb, g, 0, 1.45, 0);
    }
  }

  function buildCharacter(ch) {
    const root = new T.Group(), body = new T.Group(), mats = [];
    root.add(body);
    const c = ch.look, eq = ch.equipped, cls = ch.cls;
    const w = cls === 'warrior' ? 1.16 : cls === 'assassin' ? 0.92 : 0.95;
    const skin = mat(c.skin), cloth = mat(c.cloth);
    const armorIt = eq.armor, tier = armorIt ? armorIt.look.tier : 0;
    const metalC = METAL[armorIt ? armorIt.rarity : 0];
    const plate = mat(metalC, { metalness: 0.75, roughness: 0.38 });
    const dark = mat(0x3d2e24), leather = mat(0x5a3a22), hair = mat(c.hair, { roughness: 0.8 });
    mats.push(skin, cloth, plate, dark, leather, hair);

    const torso = part(new T.CylinderGeometry(0.33 * w, 0.2 * w, 0.68, 14), cloth, body, 0, 1.22, 0);
    torso.scale.z = 0.72;
    part(new T.SphereGeometry(0.22 * w, 12, 8), cloth, body, 0, 0.88, 0).scale.z = 0.8;
    part(new T.CylinderGeometry(0.075, 0.09, 0.14, 8), skin, body, 0, 1.61, 0);
    part(new T.CylinderGeometry(0.235 * w, 0.235 * w, 0.075, 14), leather, body, 0, 0.93, 0).scale.z = 0.8;
    part(new T.BoxGeometry(0.1, 0.1, 0.03), mat(0xc9a24a, { metalness: 0.8, roughness: 0.35 }), body, 0, 0.93, 0.19 * w);
    if (cls !== 'mage') part(new T.BoxGeometry(0.3 * w, 0.42, 0.04), cloth, body, 0, 0.7, 0.17 * w);
    if (tier >= 1) {
      part(new T.CylinderGeometry(0.345 * w, 0.24 * w, 0.44, 14), plate, body, 0, 1.31, 0.005).scale.z = 0.76;
    }
    if (cls === 'mage') part(new T.ConeGeometry(0.42, 0.95, 14, 1, true), cloth, body, 0, 0.5, 0).material.side = T.DoubleSide;

    const head = new T.Group(); head.position.set(0, 1.75, 0); head.scale.setScalar(0.8); body.add(head);
    part(new T.SphereGeometry(0.2, 16, 12), skin, head, 0, 0, 0);
    [-0.075, 0.075].forEach(x => part(new T.SphereGeometry(0.024, 6, 6), dark, head, x, 0.02, 0.18));
    const helm = eq.helmet;
    if (helm) {
      const hm = mat(METAL[helm.rarity], { metalness: 0.8, roughness: 0.35 }); mats.push(hm);
      const cap = part(new T.SphereGeometry(0.225, 14, 8, 0, Math.PI * 2, 0, Math.PI * 0.56), hm, head, 0, 0.015, -0.01);
      cap.scale.y = 1.08;
      const v = helm.look.variant;
      if (v === 1) [-1, 1].forEach(s => {
        const h = part(new T.ConeGeometry(0.05, 0.3, 6), mat(0xe8dcc2), head, s * 0.24, 0.17, 0);
        h.rotation.z = -s * 0.7;
      });
      if (v === 2) part(new T.BoxGeometry(0.05, 0.14, 0.4), mat(0xb5301f), head, 0, 0.27, -0.03);
      if (v === 3) for (let i = 0; i < 6; i++) {
        const a = i / 6 * 6.28;
        part(new T.ConeGeometry(0.04, 0.14, 4), hm, head, Math.sin(a) * 0.18, 0.22, Math.cos(a) * 0.18);
      }
    } else {
      const h = part(new T.SphereGeometry(0.215, 14, 8, 0, Math.PI * 2, 0, Math.PI * 0.52), hair, head, 0, 0.03, -0.03);
      h.rotation.x = -0.3;
    }

    const arm = sx => {
      const g = new T.Group(); g.position.set(sx * 0.37 * w, 1.47, 0); body.add(g);
      part(new T.CapsuleGeometry(0.075 * w, 0.36, 3, 8), tier >= 2 ? plate : cloth, g, 0, -0.24, 0);
      const hand = new T.Group(); hand.position.set(0, -0.54, 0); g.add(hand);
      part(new T.SphereGeometry(0.075, 8, 6), skin, hand);
      if (tier >= 2) part(new T.SphereGeometry(0.15 * w, 10, 8), plate, g, 0, 0, 0).scale.y = 0.75;
      return { g, hand };
    };
    const armR = arm(1), armL = arm(-1);
    const leg = sx => {
      const g = new T.Group(); g.position.set(sx * 0.14 * w, 0.84, 0); body.add(g);
      part(new T.CapsuleGeometry(0.09 * w, 0.46, 3, 8), dark, g, 0, -0.34, 0);
      part(new T.CapsuleGeometry(0.095, 0.16, 3, 8), tier >= 1 ? plate : leather, g, 0, -0.62, 0);
      part(new T.BoxGeometry(0.16, 0.09, 0.28), tier >= 1 ? plate : leather, g, 0, -0.79, 0.05);
      return g;
    };
    const legR = leg(1), legL = leg(-1);

    if (tier >= 3) { // pelerin
      const capeMat = mat(c.cloth, { side: T.DoubleSide }); mats.push(capeMat);
      const cape = part(new T.PlaneGeometry(0.66 * w, 1.15), capeMat, body, 0, 0.92, -0.3);
      cape.rotation.x = 0.13;
    }
    const acc = eq.accessory;
    if (acc) {
      const ac = [0xc8c8c8, 0x7dffb4, 0x66c8ff, 0xc77dff, 0xffaa33][acc.rarity];
      const am = mat(ac, { emissive: ac, emissiveIntensity: 1.3 }); mats.push(am);
      part(new T.OctahedronGeometry(0.055), am, body, 0, 1.42, 0.3 * w);
    }
    buildWeapon(eq.weapon, armR.hand, mats);
    if (eq.weapon && eq.weapon.type === 'dagger') buildWeapon(eq.weapon, armL.hand, mats);

    const blob = new T.Mesh(new T.CircleGeometry(0.55, 24), new T.MeshBasicMaterial({ color: 0xffc44d, transparent: true, opacity: 0 }));
    blob.rotation.x = -Math.PI / 2; blob.position.y = 0.02; root.add(blob);
    root.traverse(o => { if (o.isMesh && o.material && !mats.includes(o.material) && o !== blob) mats.push(o.material); });
    if (ch.boss) root.scale.setScalar(1.35);
    return { root, body, head, armR, armL, legR, legL, mats, blob, torso };
  }

  class View {
    constructor(ch, ent) {
      Object.assign(this, buildCharacter(ch));
      this.ent = ent; this.ph = Math.random() * 6; this.atk = 0; this.cast = 0; this.flash = 0; this.dead = 0; this.spin = 0;
      scene.add(this.root);
    }
    trigger(kind) {
      if (kind === 'attack') this.atk = 0.42;
      if (kind === 'cast') this.cast = 0.55;
      if (kind === 'spin') this.spin = 0.5;
      if (kind === 'hit') this.flash = 0.13;
    }
    update(dt) {
      const e = this.ent; this.ph += dt;
      let moving = false, stunned = false;
      if (e) {
        const k = 1 - Math.exp(-dt * 18);
        this.root.position.x += (e.x - this.root.position.x) * k;
        this.root.position.z += (e.z - this.root.position.z) * k;
        let da = e.face - this.root.rotation.y;
        da = Math.atan2(Math.sin(da), Math.cos(da));
        this.root.rotation.y += da * k;
        moving = e.moving; stunned = e.fx.some(f => f.type === 'stun');
      }
      const t = this.ph;
      const walk = moving ? Math.sin(t * 11) : 0, breathe = Math.sin(t * 2.2);
      this.legR.rotation.x = walk * 0.8; this.legL.rotation.x = -walk * 0.8;
      this.body.position.y = moving ? Math.abs(Math.sin(t * 11)) * 0.05 : breathe * 0.012;
      let rx = -0.25 - walk * 0.6 + breathe * 0.03, rz = 0.06, lx = walk * 0.6 + breathe * 0.03, lz = -0.08;
      if (this.atk > 0) {
        this.atk -= dt;
        const p = 1 - this.atk / 0.42;
        rx = p < 0.45 ? -0.25 - p / 0.45 * 2.3 : -2.55 + (p - 0.45) / 0.55 * 3.1;
        this.body.rotation.x = Math.sin(p * Math.PI) * 0.16;
      } else this.body.rotation.x *= 0.8;
      if (this.cast > 0) {
        this.cast -= dt;
        const p = Math.sin((1 - this.cast / 0.55) * Math.PI);
        rx = -0.25 - p * 2.5; lx = -p * 2.5;
      }
      if (this.spin > 0) { this.spin -= dt; this.body.rotation.y += dt * 22; rx = -1.6; lx = -1.6; rz = 0.5; lz = -0.5; }
      else this.body.rotation.y = 0;
      this.armR.g.rotation.x = rx; this.armR.g.rotation.z = rz; this.armL.g.rotation.x = lx; this.armL.g.rotation.z = lz;
      this.head.rotation.z = stunned ? Math.sin(t * 12) * 0.25 : 0;
      if (this.flash > 0) this.flash -= dt;
      const hot = this.flash > 0;
      if (hot !== this.wasHot) {
        this.wasHot = hot;
        for (const m of this.mats) {
          if (m.userData.em === undefined) { m.userData.em = m.emissive ? m.emissive.getHex() : 0; m.userData.ei = m.emissiveIntensity; }
          if (m.emissive) { m.emissive.setHex(hot ? 0xff3322 : m.userData.em); m.emissiveIntensity = hot ? 1.1 : m.userData.ei; }
        }
      }
      if (e && !e.alive) {
        this.dead += dt;
        this.body.rotation.x = -Math.min(1.5, this.dead * 3.5);
        this.body.position.y = Math.min(0.12, this.dead);
      }
    }
    remove() { scene.remove(this.root); this.root.traverse(o => { if (o.geometry) o.geometry.dispose(); }); this.mats.forEach(m => m.dispose()); }
  }

  // ---- Efektler ----
  function spark(x, y, z, color, n, spread, size, life) {
    for (let i = 0; i < n; i++) {
      const s = sprites.find(p => p.life <= 0);
      if (!s) return;
      s.life = s.max = (life || 0.5) * (0.6 + Math.random() * 0.6);
      s.size = (size || 0.3) * (0.6 + Math.random() * 0.8);
      s.spr.visible = true; s.spr.position.set(x, y, z); s.spr.material.color.setHex(color);
      const a = Math.random() * 6.28, v = spread * (0.3 + Math.random());
      s.vx = Math.sin(a) * v; s.vz = Math.cos(a) * v; s.vy = (Math.random() * 1.2 - 0.1) * spread;
    }
  }
  function ring(x, z, r, color, dur) {
    const m = new T.Mesh(new T.RingGeometry(0.82, 1, 48), new T.MeshBasicMaterial({ color, transparent: true, blending: T.AdditiveBlending, side: T.DoubleSide, depthWrite: false }));
    m.rotation.x = -Math.PI / 2; m.position.set(x, 0.06, z); scene.add(m);
    rings.push({ m, t: 0, dur: dur || 0.45, r });
  }

  const FX = { fire: 0xff7a22, bolt: 0x8fb4ff };
  const ACOL = { whirl: 0xffb060, nova: 0x8fe0ff, meteor: 0xff6a1e };

  function init(canvas) {
    renderer = new T.WebGLRenderer({ canvas, antialias: true });
    renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    renderer.shadowMap.enabled = true; renderer.shadowMap.type = T.PCFSoftShadowMap;
    renderer.toneMapping = T.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
    scene = new T.Scene();
    scene.background = canvasTex(256, (ctx, s) => {
      const g = ctx.createLinearGradient(0, 0, 0, s);
      g.addColorStop(0, '#0b0a18'); g.addColorStop(0.55, '#2a1420'); g.addColorStop(0.8, '#6b2a18'); g.addColorStop(1, '#1a0f0c');
      ctx.fillStyle = g; ctx.fillRect(0, 0, s, s);
    });
    scene.fog = new T.Fog(0x24121a, 28, 62);
    camera = new T.PerspectiveCamera(46, 1, 0.1, 150);
    clock = new T.Clock();
    sparkTex = canvasTex(64, (ctx, s) => {
      const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
      g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.35, 'rgba(255,255,255,.55)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      ctx.fillStyle = g; ctx.fillRect(0, 0, s, s);
    });
    // Metal yuzeylerin siyah gorunmemesi icin yansitacaklari bir ortam dokusu
    const env = canvasTex(256, (ctx, s) => {
      const g = ctx.createLinearGradient(0, 0, 0, s);
      g.addColorStop(0, '#8d93b8'); g.addColorStop(0.45, '#d8a878'); g.addColorStop(0.55, '#a5512a'); g.addColorStop(1, '#3a2a22');
      ctx.fillStyle = g; ctx.fillRect(0, 0, s, s);
    });
    env.mapping = T.EquirectangularReflectionMapping; scene.environment = env;
    scene.add(new T.HemisphereLight(0x9aa6d0, 0x3a2418, 0.7));
    const sun = new T.DirectionalLight(0xffd9b0, 2.3);
    sun.position.set(7, 16, 9); sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    Object.assign(sun.shadow.camera, { left: -15, right: 15, top: 15, bottom: -15, near: 1, far: 40 });
    sun.shadow.bias = -0.0006; scene.add(sun);
    buildArena();
    for (let i = 0; i < 220; i++) {
      const spr = new T.Sprite(new T.SpriteMaterial({ map: sparkTex, blending: T.AdditiveBlending, transparent: true, depthWrite: false }));
      spr.visible = false; scene.add(spr);
      sprites.push({ spr, life: 0, max: 1, size: 1, vx: 0, vy: 0, vz: 0 });
    }
    addEventListener('resize', resize); resize();
    let drag = null;
    canvas.addEventListener('pointerdown', e => { drag = { x: e.clientX, y: e.clientY, moved: 0 }; });
    addEventListener('pointerup', () => { drag = null; });
    addEventListener('pointermove', e => {
      if (!drag) return;
      const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
      drag.x = e.clientX; drag.y = e.clientY;
      if (cam.mode === 'hub') { if (preview) preview.root.rotation.y += dx * 0.012; return; }
      cam.yaw -= dx * 0.006; cam.pitch = Math.max(0.2, Math.min(1.25, cam.pitch + dy * 0.004));
    });
    canvas.addEventListener('wheel', e => {
      if (cam.mode === 'battle') cam.dist = Math.max(7, Math.min(21, cam.dist + e.deltaY * 0.01));
    }, { passive: true });
  }

  function resize() {
    renderer.setSize(innerWidth, innerHeight, false);
    camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
  }

  function showPreview(ch) {
    let ry = 0.35;
    if (preview) { ry = preview.root.rotation.y; preview.remove(); }
    preview = new View(ch, null); preview.root.rotation.y = ry;
    cam.mode = 'hub';
  }
  function clearPreview() { if (preview) { preview.remove(); preview = null; } }

  function startBattle(battle) {
    clearPreview(); clearBattle();
    views = battle.ents.map(e => {
      const v = new View(e.ch, e);
      v.root.position.set(e.x, 0, e.z); v.root.rotation.y = e.face;
      if (e.team === 0) { v.blob.material.opacity = 0.28; v.blob.material.color.setHex(0x66c8ff); }
      return v;
    });
    Object.assign(cam, { mode: 'battle', yaw: 0.0, pitch: 0.55, dist: 15 });
  }
  function clearBattle() {
    views.forEach(v => v.remove()); views = [];
    shots.forEach(s => scene.remove(s.m)); shots = [];
    rings.forEach(r => scene.remove(r.m)); rings = [];
    sprites.forEach(s => { s.life = 0; s.spr.visible = false; });
  }

  function onEvent(ev, battle) {
    const v = ev.ent !== undefined ? views[ev.ent] : null;
    switch (ev.t) {
      case 'attack': v.trigger('attack'); break;
      case 'cast': {
        const sk = DF.SKILLS[ev.skill];
        if (ev.skill === 'whirl') v.trigger('spin'); else if (sk.kind === 'melee') v.trigger('attack'); else v.trigger('cast');
        const e = battle.ents[ev.ent];
        if (sk.kind === 'self') { ring(e.x, e.z, 2, ev.skill === 'barrier' ? 0x7a8cff : 0xffd070, 0.6); spark(e.x, 1.2, e.z, ev.skill === 'barrier' ? 0x7a8cff : 0xffd070, 22, 1.8, 0.28, 0.7); }
        break;
      }
      case 'hit': {
        const e = battle.ents[ev.ent]; v.trigger('hit');
        spark(e.x, 1.3, e.z, ev.dot ? 0x6fe04a : 0xff4a2a, ev.crit ? 24 : 9, ev.crit ? 3.2 : 1.8, 0.22, 0.4);
        if (ev.crit) { cheer = 1.5; cam.shake = 0.22; }
        break;
      }
      case 'death': cheer = 3; cam.shake = 0.3; break;
      case 'proj': {
        const c = FX[ev.fx];
        const m = new T.Mesh(new T.SphereGeometry(ev.fx === 'fire' ? 0.3 : 0.15, 12, 8), new T.MeshBasicMaterial({ color: c }));
        m.position.set(ev.idx.x, 1.4, ev.idx.z); scene.add(m);
        shots.push({ m, p: ev.idx, c, size: ev.fx === 'fire' ? 0.45 : 0.22 });
        break;
      }
      case 'telegraph': {
        ring(ev.x, ev.z, ev.r, 0xff5a1e, ev.dur);
        const m = new T.Mesh(new T.IcosahedronGeometry(0.85, 0), new T.MeshBasicMaterial({ color: 0xff7a22 }));
        m.position.set(ev.x + 5, 16, ev.z - 4); scene.add(m);
        shots.push({ m, meteor: { sx: ev.x + 5, sz: ev.z - 4, x: ev.x, z: ev.z, t: 0, dur: ev.dur }, c: 0xff7a22, size: 0.9 });
        break;
      }
      case 'aoe': {
        const c = ACOL[ev.skill] || 0xffffff;
        ring(ev.x, ev.z, ev.r, c, 0.5);
        spark(ev.x, 0.6, ev.z, c, ev.skill === 'meteor' ? 70 : 34, ev.r * 1.4, 0.42, 0.7);
        if (ev.skill === 'meteor') { cam.shake = 0.5; cheer = 2; }
        break;
      }
      case 'blink': { const e = battle.ents[ev.ent]; spark(e.x, 1, e.z, 0x8a5cff, 26, 2.2, 0.32, 0.5); v.root.position.set(e.x, 0, e.z); break; }
      case 'miss': { const e = battle.ents[ev.ent]; spark(e.x, 1.4, e.z, 0xffffff, 5, 1, 0.14, 0.3); break; }
    }
  }

  const tmp = new T.Vector3();
  function project(x, y, z) {
    tmp.set(x, y, z).project(camera);
    return { x: (tmp.x + 1) / 2 * innerWidth, y: (1 - tmp.y) / 2 * innerHeight, vis: tmp.z < 1 };
  }

  const m4 = new T.Matrix4();
  function render() {
    const dt = Math.min(0.05, clock.getDelta()), time = clock.elapsedTime;
    if (preview) { preview.update(dt); if (!preview.dragged) preview.root.rotation.y += dt * 0.28; }
    views.forEach(v => v.update(dt));

    for (const s of sprites) {
      if (s.life <= 0) continue;
      s.life -= dt;
      if (s.life <= 0) { s.spr.visible = false; continue; }
      s.spr.position.x += s.vx * dt; s.spr.position.y += s.vy * dt; s.spr.position.z += s.vz * dt;
      s.vy -= 2 * dt;
      const k = s.life / s.max;
      s.spr.material.opacity = k; s.spr.scale.setScalar(s.size * (0.5 + k));
    }
    rings = rings.filter(r => {
      r.t += dt; const k = r.t / r.dur;
      r.m.scale.setScalar(r.r * Math.min(1, 0.2 + k)); r.m.material.opacity = 1 - k * k;
      if (k >= 1) { scene.remove(r.m); r.m.geometry.dispose(); r.m.material.dispose(); return false; }
      return true;
    });
    shots = shots.filter(s => {
      if (s.meteor) {
        const q = s.meteor; q.t += dt; const k = Math.min(1, q.t / q.dur);
        s.m.position.set(q.sx + (q.x - q.sx) * k, 16 * (1 - k) + 0.3, q.sz + (q.z - q.sz) * k);
        s.m.rotation.x += dt * 5;
        if (k >= 1) { scene.remove(s.m); return false; }
      } else {
        s.m.position.x += (s.p.x - s.m.position.x) * 0.6; s.m.position.z += (s.p.z - s.m.position.z) * 0.6;
        if (s.p.done) {
          spark(s.m.position.x, 1.4, s.m.position.z, s.c, 16, 2.2, 0.3, 0.4);
          scene.remove(s.m); return false;
        }
      }
      spark(s.m.position.x, s.m.position.y, s.m.position.z, s.c, 1, 0.3, s.size, 0.3);
      return true;
    });

    flames.forEach(f => {
      const n = Math.sin(time * 9 + f.userData.ph) * 0.12 + Math.sin(time * 17 + f.userData.ph) * 0.08;
      f.scale.set(1.8 + n, 2.6 + n * 2.4, 1);
    });
    torchLights.forEach((l, i) => { l.intensity = 60 + Math.sin(time * 8 + i * 2) * 10; });
    cheer = Math.max(0, cheer - dt * 0.8);
    crowdData.forEach((d, i) => {
      m4.setPosition(d.x, d.y + Math.max(0, Math.sin(time * (2 + cheer * 3) + d.ph)) * (0.04 + cheer * 0.17), d.z);
      crowd.setMatrixAt(i, m4);
    });
    crowd.instanceMatrix.needsUpdate = true;
    const ep = embers.geometry.attributes.position;
    for (let i = 0; i < ep.count; i++) {
      let y = ep.getY(i) + dt * (0.4 + (i % 5) * 0.12);
      if (y > 10) y = 0;
      ep.setY(i, y);
    }
    ep.needsUpdate = true;

    if (cam.mode === 'hub') {
      // Karakter sag tarafa alinir: sol taraf menu panelleri icin bos kalir.
      const wide = innerWidth > 800;
      camera.position.set(wide ? -0.7 : 0, 1.5, 5.1);
      camera.lookAt(wide ? -0.7 : 0, 1.12, 0);
    } else {
      let mx = 0, mz = 0, n = 0;
      views.forEach(v => { if (v.ent.alive) { mx += v.root.position.x; mz += v.root.position.z; n++; } });
      if (n) { mx /= n; mz /= n; }
      cam.tx += (mx - cam.tx) * 0.06; cam.tz += (mz - cam.tz) * 0.06;
      const sh = cam.shake || 0;
      cam.shake = Math.max(0, sh - dt);
      const ch = Math.cos(cam.pitch) * cam.dist;
      camera.position.set(cam.tx + Math.sin(cam.yaw) * ch + (Math.random() - 0.5) * sh, Math.sin(cam.pitch) * cam.dist + 1 + (Math.random() - 0.5) * sh, cam.tz + Math.cos(cam.yaw) * ch);
      camera.lookAt(cam.tx, 1.1, cam.tz);
    }
    renderer.render(scene, camera);
  }

  function pickEnt(cx, cy) { // tiklanan rakibi ekran mesafesiyle bulur
    let best = null, bd = 90;
    views.forEach(v => {
      if (!v.ent.alive || v.ent.team === 0) return;
      const p = project(v.root.position.x, 1.2, v.root.position.z);
      const d = Math.hypot(p.x - cx, p.y - cy);
      if (d < bd) { bd = d; best = v.ent; }
    });
    return best;
  }
  function markTarget(ent) {
    views.forEach(v => { if (v.ent.team !== 0) { v.blob.material.opacity = v.ent === ent && v.ent.alive ? 0.4 : 0; v.blob.material.color.setHex(0xff5a3a); } });
  }

  DF.Gfx = { init, render, showPreview, clearPreview, startBattle, clearBattle, onEvent, project, pickEnt, markTarget };
})();
