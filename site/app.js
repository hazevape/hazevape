const $ = id => document.getElementById(id);
const API = String(window.KEYFORGE_API || '').replace(/\/$/, '');
let token = sessionStorage.getItem('keyforgeToken') || '';
let user = null, mode='login', lastGenerated=[];
function toast(msg) { $('toast').textContent=msg; $('toast').style.display='block'; clearTimeout(window.toastTimer); window.toastTimer=setTimeout(()=>$('toast').style.display='none',4500); }
async function api(path, body, method) {
 const r=await fetch(`${API}/api/${path}`,{method:method || (body===undefined?'GET':'POST'),headers:{'Content-Type':'application/json',...(token?{'Authorization':`Bearer ${token}`}:{})},body:body===undefined?undefined:JSON.stringify(body)});
 const result=await r.json().catch(()=>({error:'Invalid API response'}));
 if(!r.ok) throw new Error(result.error || `Request failed (${r.status})`);
 return result;
}
function el(tag,text,cls) {const e=document.createElement(tag);e.textContent=text??'';if(cls)e.className=cls;return e;}
function cell(row,text,cls){const td=el('td',text,cls);row.append(td);return td;}
function table(headers,records,makeRow){const t=el('table');const th=el('tr');headers.forEach(h=>th.append(el('th',h)));const head=el('thead');head.append(th);t.append(head);const body=el('tbody');records.forEach(r=>body.append(makeRow(r)));t.append(body);return t;}
function presentDate(d) {return d?new Date(d.replace(' ','T')+(d.includes('Z')?'':'Z')).toLocaleDateString():'Never';}
function active(k){return !k.revoked && (!k.expires_at || new Date(k.expires_at.replace(' ','T')+'Z')>new Date());}
function showAuth(){user=null;$('authPage').hidden=false;$('dashboard').hidden=true;$('logout').hidden=true;$('identity').textContent='';}
function showDash(u){user=u;$('authPage').hidden=true;$('dashboard').hidden=false;$('logout').hidden=false;$('identity').textContent=u.email;$('accountRole').textContent=u.admin?'Admin':'Member';$('admin').hidden=!u.admin;loadKeys();if(u.admin)loadAdmin();}
function setMode(m){mode=m;$('authHeading').textContent=m==='login'?'Welcome back':'Create an account';$('authSubmit').textContent=m==='login'?'Log in →':'Create account →';$('loginTab').classList.toggle('selected',m==='login');$('registerTab').classList.toggle('selected',m==='register');$('password').autocomplete=m==='login'?'current-password':'new-password';}
$('loginTab').onclick=()=>setMode('login');$('registerTab').onclick=()=>setMode('register');
$('authForm').onsubmit=async ev=>{ev.preventDefault();const button=$('authSubmit');button.disabled=true;try{const r=await api(mode==='login'?'login':'register',{email:$('email').value,password:$('password').value});token=r.token;sessionStorage.setItem('keyforgeToken',token);showDash(r.user);toast('Signed in successfully');$('password').value='';}catch(e){toast(e.message)}finally{button.disabled=false}};
$('logout').onclick=async()=>{try{await api('logout',{})}catch{}token='';sessionStorage.removeItem('keyforgeToken');showAuth();};
async function loadKeys(){try{const r=await api('my-keys');$('totalKeys').textContent=r.keys.length;$('activeKeys').textContent=r.keys.filter(active).length;const node=$('myKeys');node.replaceChildren();if(!r.keys.length){node.textContent='No licenses yet. Redeem one above.';return;}node.append(table(['Key','Label','Status','Expiration','Roblox User ID'],r.keys,k=>{const row=el('tr');cell(row,k.key_prefix);cell(row,k.label||'—');cell(row,active(k)?'Active':'Expired / revoked',active(k)?'ok':'bad');cell(row,presentDate(k.expires_at));cell(row,k.roblox_user_id||'Not bound');return row;}));}catch(e){toast(e.message)}}
$('redeemForm').onsubmit=async ev=>{ev.preventDefault();try{await api('redeem',{key:$('redeemInput').value});$('redeemInput').value='';toast('License redeemed');await loadKeys();}catch(e){toast(e.message)}};
$('refresh').onclick=loadKeys;
$('keyKind').onchange=()=>{$('daysField').hidden=$('keyKind').value!=='days';};
$('createForm').onsubmit=async ev=>{ev.preventDefault();const button=ev.submitter;button.disabled=true;try{const result=await api('admin/create',{label:$('keyLabel').value,kind:$('keyKind').value,days:Number($('keyDays').value),count:Number($('keyCount').value)});lastGenerated=result.created.map(k=>k.key);$('generatedText').textContent=lastGenerated.join('\n');$('generated').hidden=false;toast(`Created ${lastGenerated.length} key(s)`);await loadAdmin();}catch(e){toast(e.message)}finally{button.disabled=false}};
$('copyKeys').onclick=async()=>{try{await navigator.clipboard.writeText(lastGenerated.join('\n'));toast('Keys copied');}catch{toast('Select the keys above and copy them manually');}};
async function loadAdmin(){try{const r=await api('admin/keys');const node=$('adminKeys');node.replaceChildren();if(!r.keys.length){node.textContent='No keys created yet.';return;}node.append(table(['Key','Label','Duration','Claimed by','Status','Action'],r.keys,k=>{const row=el('tr');cell(row,k.key_prefix);cell(row,k.label||'—');cell(row,k.duration_days?`${k.duration_days} days`:'Lifetime');cell(row,k.redeemed_email||'Unclaimed');cell(row,k.revoked?'Revoked':active(k)?'Active':'Expired',k.revoked?'bad':'ok');const td=cell(row,'');if(!k.revoked){const btn=el('button','Revoke','muted');btn.onclick=async()=>{if(!confirm(`Revoke ${k.key_prefix}? This cannot be undone.`))return;try{await api('admin/revoke',{id:k.id});toast('Key revoked');loadAdmin();}catch(e){toast(e.message)}};td.append(btn);}return row;}));}catch(e){toast(e.message)}}
$('adminRefresh').onclick=loadAdmin;
(async()=>{if(API.includes('YOUR_SUBDOMAIN')){toast('Configure site/config.js with your Worker URL first');}if(token){try{const r=await api('me');showDash(r.user);}catch{token='';sessionStorage.removeItem('keyforgeToken');showAuth();}}else showAuth();})();
