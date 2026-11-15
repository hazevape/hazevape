const encoder = new TextEncoder();
const hex = b => Array.from(new Uint8Array(b), x => x.toString(16).padStart(2, '0')).join('');
const randomHex = bytes => { const a = crypto.getRandomValues(new Uint8Array(bytes)); return hex(a); };
const sha256 = async text => hex(await crypto.subtle.digest('SHA-256', encoder.encode(text)));
async function passwordHash(password, saltHex) {
  const salt = new Uint8Array(saltHex.match(/.{2}/g).map(x => parseInt(x, 16)));
  const key = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']);
  return hex(await crypto.subtle.deriveBits({name: 'PBKDF2', hash: 'SHA-256', salt, iterations: 210000}, key, 256));
}
const isoAfter = days => new Date(Date.now() + days * 86400000).toISOString();
const json = (data, status = 200, extra = {}) => new Response(JSON.stringify(data), {status, headers: {'Content-Type':'application/json; charset=utf-8', 'Cache-Control':'no-store', ...extra}});
const fail = (message, status=400) => json({error:message}, status);
const normalize = s => String(s || '').trim();
const validEmail = s => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s) && s.length <= 254;
const noStore = {'Cache-Control':'no-store'};

async function rateLimit(env, bucket, limit, seconds) {
 const now = Math.floor(Date.now()/1000);
 await env.DB.prepare('DELETE FROM rate_limits WHERE resets_at < ?').bind(now).run();
 await env.DB.prepare(`INSERT INTO rate_limits(bucket,count,resets_at) VALUES(?,1,?)
  ON CONFLICT(bucket) DO UPDATE SET count=CASE WHEN resets_at <= ? THEN 1 ELSE count+1 END,
  resets_at=CASE WHEN resets_at <= ? THEN ? ELSE resets_at END`).bind(bucket, now + seconds, now, now, now + seconds).run();
 const row = await env.DB.prepare('SELECT count FROM rate_limits WHERE bucket=?').bind(bucket).first();
 return row.count > limit;
}
async function sessionUser(request, env) {
 const header = request.headers.get('Authorization') || '';
 if (!/^Bearer [a-f0-9]{64}$/i.test(header)) return null;
 const h = await sha256(header.slice(7));
 return await env.DB.prepare(`SELECT u.id,u.email,u.is_admin,s.token_hash FROM sessions s
 JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>?`)
 .bind(h,new Date().toISOString()).first();
}
async function bodyJson(request) {
 if (Number(request.headers.get('Content-Length') || 0) > 8192) throw Error('Request too large');
 const s = await request.text();
 if (s.length > 8192) throw Error('Request too large');
 try { return JSON.parse(s); } catch { throw Error('Invalid JSON'); }
}
async function makeSession(env,userId) {
 const token=randomHex(32);
 await env.DB.prepare('INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,?)')
  .bind(await sha256(token), userId, isoAfter(14)).run();
 return token;
}
const publicUser = u => ({email:u.email,admin:!!u.is_admin});

export default {
 async fetch(request, env) {
  const origin = request.headers.get('Origin');
  const allowed = env.SITE_ORIGIN;
  const cors = origin === allowed ? {'Access-Control-Allow-Origin': allowed,'Vary':'Origin', 'Access-Control-Allow-Headers':'Authorization, Content-Type', 'Access-Control-Allow-Methods':'GET, POST, OPTIONS'} : {};
  if(request.method==='OPTIONS') return new Response(null,{status:204, headers:cors});
  const respond = r => {const h = new Headers(r.headers); Object.entries(cors).forEach(([k,v])=>h.set(k,v)); return new Response(r.body,{status:r.status,headers:h});};
  try {
   const url=new URL(request.url), path=url.pathname;
   if(path==='/api/health' && request.method==='GET') return respond(json({ok:true}));
   if(!path.startsWith('/api/')) return respond(fail('Not found',404));
   if(!['GET','POST'].includes(request.method)) return respond(fail('Method not allowed',405));
   const ip=request.headers.get('CF-Connecting-IP') || 'unknown';
   if(path==='/api/register' && request.method==='POST') {
    if(await rateLimit(env,`register:${ip}`,5,3600)) return respond(fail('Too many registrations; retry later',429));
    const b=await bodyJson(request),email=normalize(b.email).toLowerCase(),password=String(b.password||'');
    if(!validEmail(email)||password.length<12||password.length>128) return respond(fail('Enter a valid email and a password of 12–128 characters'));
    const id=crypto.randomUUID(),salt=randomHex(16),ph=await passwordHash(password,salt);
    try { await env.DB.prepare('INSERT INTO users(id,email,password_salt,password_hash) VALUES(?,?,?,?)').bind(id,email,salt,ph).run(); }
    catch {return respond(fail('Email is already registered',409));}
    return respond(json({token:await makeSession(env,id),user:{email,admin:false}},201));
   }
   if(path==='/api/login' && request.method==='POST') {
    if(await rateLimit(env,`login:${ip}`,20,900)) return respond(fail('Too many login attempts; retry later',429));
    const b=await bodyJson(request),email=normalize(b.email).toLowerCase(),password=String(b.password||'');
    const u=await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(email).first();
    if(!u || !(await passwordHash(password,u.password_salt)===u.password_hash)) return respond(fail('Incorrect email or password',401));
    return respond(json({token:await makeSession(env,u.id),user:publicUser(u)}));
   }
   // Verification is used by Roblox server scripts. A license must first be redeemed.
   if(path==='/api/verify' && request.method==='POST') {
    if(await rateLimit(env,`verify:${ip}`,120,3600)) return respond(fail('Too many verification requests',429));
    const b=await bodyJson(request),raw=normalize(b.key).toUpperCase(),player=normalize(b.robloxUserId);
    if(!/^RBX-[A-F0-9]{8}(-[A-F0-9]{8}){3}$/.test(raw) || !/^\d{1,20}$/.test(player)) return respond(json({valid:false,reason:'Invalid key or Roblox user ID'}));
    const h=await sha256(raw);
    const now=new Date().toISOString();
    const result=await env.DB.prepare(`UPDATE licenses SET roblox_user_id=COALESCE(roblox_user_id,?)
     WHERE key_hash=? AND revoked=0 AND redeemed_by IS NOT NULL AND (expires_at IS NULL OR expires_at>?)
     AND (roblox_user_id IS NULL OR roblox_user_id=?)`).bind(player,h,now,player).run();
    if(!result.meta.changes) return respond(json({valid:false,reason:'Inactive, expired, or bound to a different Roblox account'}));
    const license=await env.DB.prepare('SELECT expires_at,label FROM licenses WHERE key_hash=?').bind(h).first();
    return respond(json({valid:true,label:license.label,expiresAt:license.expires_at}));
   }
   const user=await sessionUser(request,env);
   if(!user) return respond(fail('Please log in',401));
   if(path==='/api/me' && request.method==='GET') return respond(json({user:publicUser(user)}));
   if(path==='/api/logout' && request.method==='POST') {
    await env.DB.prepare('DELETE FROM sessions WHERE token_hash=?').bind(user.token_hash).run();
    return respond(json({ok:true}));
   }
   if(path==='/api/my-keys' && request.method==='GET') {
    const r=await env.DB.prepare(`SELECT id,key_prefix,label,expires_at,revoked,roblox_user_id,redeemed_at FROM licenses WHERE redeemed_by=? ORDER BY redeemed_at DESC`).bind(user.id).all();
    return respond(json({keys:r.results}));
   }
   if(path==='/api/redeem' && request.method==='POST') {
    if(await rateLimit(env,`redeem:${user.id}`,20,3600)) return respond(fail('Too many redemption attempts',429));
    const b=await bodyJson(request),raw=normalize(b.key).toUpperCase();
    if(!/^RBX-[A-F0-9]{8}(-[A-F0-9]{8}){3}$/.test(raw)) return respond(fail('Invalid key format'));
    const h=await sha256(raw),now=new Date().toISOString();
    const r=await env.DB.prepare(`UPDATE licenses SET redeemed_by=?,redeemed_at=?,
       expires_at=CASE WHEN duration_days IS NOT NULL THEN datetime('now', '+' || duration_days || ' days') ELSE expires_at END
       WHERE key_hash=? AND redeemed_by IS NULL AND revoked=0 AND (expires_at IS NULL OR expires_at>?)`).bind(user.id,now,h,now).run();
    if(!r.meta.changes) return respond(fail('Key not found, already used, expired, or revoked',409));
    return respond(json({ok:true}));
   }
   if(!user.is_admin) return respond(fail('Admin access required',403));
   if(path==='/api/admin/keys' && request.method==='GET') {
    const r=await env.DB.prepare(`SELECT l.id,l.key_prefix,l.label,l.duration_days,l.expires_at,l.revoked,l.redeemed_at,l.roblox_user_id,u.email AS redeemed_email
       FROM licenses l LEFT JOIN users u ON l.redeemed_by=u.id ORDER BY l.created_at DESC LIMIT 200`).all();
    return respond(json({keys:r.results}));
   }
   if(path==='/api/admin/create' && request.method==='POST') {
    const b=await bodyJson(request),label=normalize(b.label).slice(0,70),kind=normalize(b.kind);
    const days=Number(b.days);
    if(kind!=='lifetime' && (kind!=='days' || !Number.isInteger(days) || days<1 || days>3650)) return respond(fail('Choose lifetime or 1–3650 days'));
    const count=Number(b.count||1);
    if(!Number.isInteger(count)||count<1||count>20) return respond(fail('Create between 1 and 20 keys'));
    const created=[];
    for(let i=0;i<count;i++) {
     const raw='RBX-'+[0,1,2,3].map(()=>randomHex(4).toUpperCase()).join('-');
     const id=crypto.randomUUID();
     await env.DB.prepare('INSERT INTO licenses(id,key_hash,key_prefix,label,created_by,duration_days) VALUES(?,?,?,?,?,?)')
      .bind(id,await sha256(raw),raw.slice(0,12)+'…',label,user.id,kind==='days'?days:null).run();
     created.push({id,key:raw,label,kind,days:kind==='days'?days:null});
    }
    return respond(json({created},201));
   }
   if(path==='/api/admin/revoke' && request.method==='POST') {
    const b=await bodyJson(request);
    if(typeof b.id !== 'string') return respond(fail('Invalid ID'));
    const r=await env.DB.prepare('UPDATE licenses SET revoked=1 WHERE id=?').bind(b.id).run();
    return respond(r.meta.changes?json({ok:true}):fail('Key not found',404));
   }
   return respond(fail('Not found',404));
  } catch(e) {
   if(e.message==='Invalid JSON'||e.message==='Request too large') return respond(fail(e.message,400));
   console.error(e);return respond(fail('Internal server error',500));
  }
 }
};
