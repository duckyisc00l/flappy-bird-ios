// A pretend phone for the build: joins the TV's party room through Supabase Realtime, says hello, flaps, and records
// what the TV tells it. Usage: node phone.js CODE seconds
const { createClient } = require('@supabase/supabase-js');
const code = process.argv[2], secs = +(process.argv[3] || 40);
const sb = createClient('https://umnmgkbzsfpockrorcqd.supabase.co', 'sb_publishable_Mtltj8MvHzXQyMHTWprIzg_DjOU2XJz', { auth: { persistSession: false } });
const id = 'ciphone' + Math.floor(Math.random() * 1e6), seen = [], log = { id, states: 0, phases: [], me: [], subscribed: null };
const ch = sb.channel('fb-party-' + code, { config: { broadcast: { self: false } } });
ch.on('broadcast', { event: 'st' }, ({ payload }) => {
  log.states++;
  if (!log.phases.length || log.phases[log.phases.length - 1] !== payload.s) log.phases.push(payload.s);
  const me = (payload.pl || []).find(p => p.id === id);
  if (me) { const k = payload.s + ' in=' + me.in + ' alive=' + me.alive + ' score=' + me.score; if (log.me[log.me.length - 1] !== k) log.me.push(k); }
  if (payload.win && payload.win.length) log.win = payload.win;
  log.players = (payload.pl || []).map(p => p.name);
  log.last = payload.s;
});
ch.subscribe((s) => { log.subscribed = s; });
const hello = () => ch.send({ type: 'broadcast', event: 'p', payload: { id, name: 'CI PHONE', bird: 'yellow' } });
const t0 = Date.now();
const h = setInterval(hello, 2000); setTimeout(hello, 1500);
const f = setInterval(() => { if (log.last === 'play') ch.send({ type: 'broadcast', event: 'f', payload: { id } }); }, 290);
setTimeout(async () => { clearInterval(h); clearInterval(f); await ch.send({ type: 'broadcast', event: 'bye', payload: { id } }); console.log(JSON.stringify(log, null, 1)); process.exit(0); }, secs * 1000);
