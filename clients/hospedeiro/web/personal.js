/* Private worlds: local simulation worker, durable journal, asynchronous cloud.
 * No personal journal is ever submitted to hosp_world or a shared match. */
(() => {
  'use strict';
  const query = new URLSearchParams(location.search);
  const enabled = query.get('mode') !== 'shared' && query.get('engine') !== 'off';
  const P = window.HospPersonal = {enabled, ready:false, error:'', cloud:'Preparando save local', peer:null, player:{}};
  let db, worker, serial=0, journal=[], cloudCount=0, cloudVersion='*', identity, universe;
  let token='', uid='', cloudBusy=false, conflicted=false, durable=Promise.resolve(), pending=new Map(), replies=new Map();
  const requestID = () => crypto.randomUUID();
  const canonical = value => JSON.stringify(value, function(_key,item){
    return item && !Array.isArray(item) && typeof item==='object' ? Object.fromEntries(Object.keys(item).sort().map(key=>[key,item[key]])) : item;
  });
  const rpc = async body => {
    if (!token) await authenticate();
    const response = await fetch('/nakama/v2/rpc/hosp_personal', {method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},body:JSON.stringify(JSON.stringify(body)),signal:AbortSignal.timeout(8000)});
    if (response.status === 401) { token=''; throw Error('Sessão expirada'); }
    if (!response.ok) throw Error('Nuvem indisponível');
    return JSON.parse((await response.json()).payload);
  };
  async function authenticate() {
    const response = await fetch('/nakama/v2/account/authenticate/device?create=true', {method:'POST',headers:{'Content-Type':'application/json',Authorization:'Basic '+btoa('hospedeiro:')},body:JSON.stringify({id:identity.device}),signal:AbortSignal.timeout(8000)});
    if (!response.ok) throw Error('Nuvem indisponível');
    token=(await response.json()).token;
    const claims=JSON.parse(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')));
    uid=claims.uid;
  }
  function transaction(mode, operation) {
    return new Promise((resolve,reject) => {
      const tx=db.transaction('world',mode), store=tx.objectStore('world');
      let value;
      operation(store, v => value=v);
      tx.oncomplete=()=>resolve(value); tx.onerror=()=>reject(tx.error); tx.onabort=()=>reject(tx.error || Error('Save abortado'));
    });
  }
  const read = key => transaction('readonly',(s,done)=>{const r=s.get(key);r.onsuccess=()=>done(r.result);});
  function persist(commands=[],checkpoint=null) {
    const offset=journal.length-commands.length;
    const meta={identity,count:journal.length,cloudCount,cloudVersion,universe:universe.id,player:structuredClone(P.player)};
    durable=durable.then(()=>transaction('readwrite',s=>{
      commands.forEach((c,i)=>s.put(c,'cmd:'+String(offset+i).padStart(12,'0')));
      s.put(meta,'meta');
      if(checkpoint)s.put(checkpoint,'checkpoint');
    })).catch(err=>{P.error='Falha ao salvar neste aparelho: '+err.message; P.cloud=P.error; throw err;});
    durable.catch(()=>{});
    return durable;
  }
  function call(data) {
    const id=++serial;
    return new Promise((resolve,reject)=>{pending.set(id,{resolve,reject});worker.postMessage({id,...data});});
  }
  P.begin = (path,body) => {
    const id=++serial;
    if(P.restoring){replies.set(id,JSON.stringify({status:409,body:{error:'restoring'}}));return id;}
    call({path,body}).then(result=>replies.set(id,JSON.stringify(result.response)),err=>replies.set(id,JSON.stringify({status:0,body:{error:String(err)}})));
    return id;
  };
  P.take = id => { const value=replies.get(id)||''; replies.delete(id); return value; };
  P.setPlayer = value => { if (!P.peer || P.peer.role==='host') P.player=value; else P.player.files=value.files; };
  P.start = async () => {
    if (!enabled) return;
    if(navigator.locks) await new Promise((resolve,reject)=>{
      navigator.locks.request('hospedeiro-personal-writer',{ifAvailable:true},async lease=>{
        if(!lease){reject(Error('Seu mundo já está aberto em outra aba. Feche essa aba antes de continuar aqui.'));return;}
        resolve();await new Promise(release=>window.addEventListener('pagehide',release,{once:true}));
      }).catch(reject);
    });
    db=await new Promise((resolve,reject)=>{const r=indexedDB.open('hospedeiro-personal-v1',1);r.onupgradeneeded=()=>r.result.createObjectStore('world');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
    const meta=await read('meta');
    identity=meta?.identity || {id:'local-'+requestID(),device:'personal-'+requestID()};
    cloudCount=meta?.cloudCount||0; cloudVersion=meta?.cloudVersion||'*'; P.player=meta?.player||{};
    universe=await read('definition') || await (await fetch('personal-universe.json')).json();
    await transaction('readwrite',s=>s.put(universe,'definition'));
    journal=await transaction('readonly',(s,done)=>{const r=s.getAll(IDBKeyRange.bound('cmd:','cmd:~'));r.onsuccess=()=>done(r.result);});
    if (meta && meta.count !== journal.length) throw Error('Save local incompleto. Exporte o backup antes de continuar.');
    worker=new Worker('personal-worker.js');
    worker.onmessage=async({data})=>{
      const waiter=pending.get(data.id); pending.delete(data.id);
      if (!waiter) return;
      if (data.error) {waiter.reject(Error(data.error));return;}
      if (data.commands?.length) {
        journal.push(...data.commands);
        try {await persist(data.commands,data.checkpoint);}catch(err){waiter.reject(err);return;}
      }
      waiter.resolve(data);
    };
    worker.onerror=event=>{P.error=String(event.message);for(const waiter of pending.values())waiter.reject(Error(P.error));pending.clear();};
    const opened=await call({op:'open',universe,commands:journal,checkpoint:await read('checkpoint')});
    P.identity=identity; P.ready=true; P.cloud='Local · aguardando sincronização';
    await persist([],opened.checkpoint);
    // Cloud restoration is offered explicitly after local play starts. Never rewind a running world.
    sync(); setInterval(sync,10000);
    window.addEventListener('pagehide',()=>persist());
    window.addEventListener('online',sync);
  };
  async function sync() {
    if (cloudBusy || conflicted || !P.ready || P.restoring) return;
    cloudBusy=true;
    try {
      await durable;
      const remote=await rpc({op:'load',offset:0});
      const count=remote.meta.count||0;
      if (count!==cloudCount || remote.version!==cloudVersion) {
        // A write may have succeeded even when its HTTP response was lost. Verify
        // the remote continuation before acknowledging it; keep the local tail.
        let cursor=cloudCount, matches=count>cloudCount && count<=journal.length;
        for(let attempt=0;matches && cursor<count && attempt<8;attempt++) {
          const part=await rpc({op:'load',offset:cursor});
          const commands=part.segment.commands;
          if(part.version!==remote.version || !Array.isArray(commands) || !commands.length || canonical(commands)!==canonical(journal.slice(cursor,cursor+commands.length))){matches=false;break;}
          cursor+=commands.length;
        }
        if(matches && cursor===count){cloudCount=count;cloudVersion=remote.version;await persist();}
        else {
        if (journal.length===cloudCount) {
          P.restoreAvailable=true; P.cloud='Save da nuvem disponível · abrir em Mundo';
        } else { conflicted=true; P.cloud='Saves diferentes · escolha em Mundo'; }
        return;
        }
      }
      // Bounded work: at most four batches per pass; play never waits on these requests.
      for(let n=0;n<4 && cloudCount<journal.length;n++) {
        const commands=journal.slice(cloudCount,cloudCount+128);
        const saved=await rpc({op:'save',base:cloudCount,version:cloudVersion,request:identity.id+':'+cloudCount,commands,player:P.player,identity,universe:universe.id,definition:cloudCount===0?JSON.stringify(universe):undefined});
        if(saved.status!==200) {conflicted=true;P.cloud='Conflito de save · escolha em Mundo';return;}
        cloudCount=saved.count;cloudVersion=saved.version;await persist();
      }
      P.cloud=cloudCount===journal.length?'Salvo na nuvem':'Local · '+(journal.length-cloudCount)+' registros pendentes';
    } catch(err) { P.cloud=P.error || 'Salvo neste aparelho · nuvem indisponível'; }
    finally {cloudBusy=false;}
  }
  P.restore = async () => {
    if(!confirm('Restaurar o save da nuvem? Seu save local será baixado como backup antes da troca.')) return;
    await P.backup();
    P.restoring=true;
    try {
    while(pending.size || cloudBusy) await new Promise(resolve=>setTimeout(resolve,20));
    await durable;
    const first=await rpc({op:'load',offset:0});
    const commands=[];let offset=0;
    while(offset<first.meta.count) {
      const batch=offset===0?first:await rpc({op:'load',offset});
      if(batch.meta.count!==first.meta.count || batch.version!==first.version) throw Error('A nuvem mudou durante a restauração. Tente novamente.');
      if(!batch.segment.commands.length)throw Error('Registro incompleto na nuvem');
      commands.push(...batch.segment.commands);offset=commands.length;
    }
    // Validate the complete replay in a separate worker before replacing the durable save.
    if(!first.definition)throw Error('A nuvem não contém a definição deste mundo');
    const definition=typeof first.definition.json==='string'?JSON.parse(first.definition.json):first.definition;
    const checker=new Worker('personal-worker.js');
    const checked=await new Promise((resolve,reject)=>{checker.onmessage=({data})=>{checker.terminate();data.error?reject(Error(data.error)):resolve(data);};checker.onerror=reject;checker.postMessage({id:1,op:'open',universe:definition,commands});});
    await transaction('readwrite',s=>{s.clear();commands.forEach((c,i)=>s.put(c,'cmd:'+String(i).padStart(12,'0')));s.put(definition,'definition');s.put(checked.checkpoint,'checkpoint');s.put({identity:first.meta.identity,count:commands.length,cloudCount:commands.length,cloudVersion:first.version,player:first.meta.player,universe:definition.id},'meta');});
    sessionStorage.setItem('hospedeiro.autoContinue','1');
    location.reload();
    } catch(err) {P.restoring=false;throw err;}
  };
  P.backup = async () => {
    await durable;
    const url=URL.createObjectURL(new Blob([JSON.stringify({version:1,identity,universe,commands:journal,player:P.player})],{type:'application/json'}));
    const a=document.createElement('a');a.href=url;a.download='hospedeiro-mundo-pessoal.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  };
  P.returnHome = async () => {if(P.returning)return;P.returning=true;await persist();sessionStorage.setItem('hospedeiro.autoContinue','1');const url=new URL(location.href);url.hash='';location.href=url.href;};
  // Capability stays in the fragment: it is not sent to static hosting or HTTP access logs.
  const incoming = new URLSearchParams(location.hash.slice(1)).get('visit');
  P.incoming=incoming||'';
  P.rpc=rpc;
  P.getCloudCount=()=>cloudCount;
})();
