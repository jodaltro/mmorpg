/* Two-player WebRTC session. Server carries SDP/ICE only, never game packets. */
(() => {
  'use strict';
  const P=window.HospPersonal;
  let pc, channel, reliable, room='', role='', after=0, polling=false, outbox=Promise.resolve(), opened=false, pingTime=0;
  const queue=[], candidates=[], fragments=new Map();
  P.partyStatus='Sozinho · mundo pessoal'; P.partyRTT=-1; P.partyModal=false;
  const sendSignal=message=>{const target=room;outbox=outbox.then(async()=>{const r=await P.rpc({op:'room-send',room:target,message});if(r.status!==200)throw Error('Convite expirou');}).catch(err=>{P.partyStatus=err.message;});return outbox;};
  const enqueue=(code,body)=>{if(queue.length<512)queue.push({code,body});};
  P.partyTake=()=>JSON.stringify(queue.splice(0,64));
  function receive(raw) {
    if(typeof raw!=='string'||raw.length>786432)return;
    let data;try{data=JSON.parse(raw);}catch{return;}
    if(data.fragment) {
      if(!Number.isInteger(data.n)||data.n<1||data.n>64||!Number.isInteger(data.i)||data.i<0||data.i>=data.n||typeof data.text!=='string'||data.text.length>12000)return;
      const old=fragments.get(data.fragment)||{at:performance.now(),parts:[],n:data.n};
      if(old.n!==data.n)return;old.parts[data.i]=data.text;fragments.set(data.fragment,old);
      for(const [key,value]of fragments)if(performance.now()-value.at>1000)fragments.delete(key);
      if(fragments.size>32)fragments.delete(fragments.keys().next().value);
      if(old.parts.filter(x=>typeof x==='string').length===old.n){fragments.delete(data.fragment);receive(old.parts.join(''));}return;
    }
    if(data.ping){if(reliable?.readyState==='open')reliable.send(JSON.stringify({pong:data.ping}));return;}
    if(data.pong){P.partyRTT=Math.round(performance.now()-data.pong);return;}
    if(!Number.isInteger(data.code)||!data.body||typeof data.body!=='object')return;
    if(role==='host') {
      if(![1,22].includes(data.code))return;
      enqueue(data.code,data.code===1?{id:'guest',input:data.body}:data.body);
    } else if([2,21,23].includes(data.code))enqueue(data.code,data.body);
  }
  function bind(c) {
    c.onmessage=event=>receive(event.data);
    c.onopen=()=>{
      if(opened || channel?.readyState!=='open' || reliable?.readyState!=='open')return;
      opened=true;P.peer={role};P.partyStatus='Conectado · PvP no mapa aberto';
      enqueue(10,{event:'join',id:role==='host'?'guest':'host',name:'Visitante'});
    };
    c.onclose=()=>{if(opened){P.partyClose(false);P.partyStatus='Amigo desconectou';}};
  }
  async function connect(nextRole,nextRoom) {
    P.partyClose(false);role=nextRole;room=nextRoom;after=0;opened=false;
    P.partyStatus='Procurando conexão direta…';P.partyRTT=-1;
    // A local test can explicitly disable external STUN. Optional TURN configuration comes from trusted hosting configuration.
    const iceServers=new URLSearchParams(location.search).get('localIce')==='1'?[]:[{urls:'stun:stun.cloudflare.com:3478'}];
    if(Array.isArray(window.HOSPEDEIRO_ICE_SERVERS))iceServers.push(...window.HOSPEDEIRO_ICE_SERVERS);
    pc=new RTCPeerConnection({iceServers});
    pc.onicecandidate=event=>{if(event.candidate)sendSignal({type:'candidate',candidate:event.candidate.toJSON()});};
    pc.onconnectionstatechange=()=>{if(['failed','disconnected'].includes(pc.connectionState))P.partyStatus='Conexão interrompida. Algumas redes exigem relay TURN; tente outra rede ou novo convite.';};
    if(role==='host') {
      channel=pc.createDataChannel('game',{ordered:false,maxRetransmits:0});
      reliable=pc.createDataChannel('control');bind(channel);bind(reliable);
    } else pc.ondatachannel=event=>{if(event.channel.label==='game')channel=event.channel;else reliable=event.channel;bind(event.channel);};
    const started=performance.now();
    const timer=setInterval(async()=>{
      if(!pc || room!==nextRoom){clearInterval(timer);return;}
      if(polling)return;polling=true;
      try{
        const r=await P.rpc({op:'room-poll',room,after});
        if(!pc || room!==nextRoom)return;
        if(r.status!==200)throw Error('Convite expirado ou fechado');
        after=r.seq;
        if(role==='host'&&r.guest&&!pc.localDescription){await pc.setLocalDescription(await pc.createOffer());await sendSignal({type:'description',description:pc.localDescription.toJSON()});}
        for(const m of Array.isArray(r.messages)?r.messages:[]) {
          const signal=m.body;
          if(signal.type==='description') {
            await pc.setRemoteDescription(signal.description);
            while(candidates.length)await pc.addIceCandidate(candidates.shift());
            if(signal.description.type==='offer'){await pc.setLocalDescription(await pc.createAnswer());await sendSignal({type:'description',description:pc.localDescription.toJSON()});}
          } else if(signal.type==='candidate'){if(pc.remoteDescription)await pc.addIceCandidate(signal.candidate);else candidates.push(signal.candidate);}
          else if(signal.type==='leave'){P.partyClose(false);P.partyStatus='Amigo saiu';}
        }
        // Once established, even signalling leaves the gameplay loop entirely.
        if(opened)clearInterval(timer);
        if(!opened&&performance.now()-started>35000)P.partyStatus='Não conectou diretamente. Tente novo convite ou outra rede; sua rede pode precisar de TURN.';
      }catch(err){P.partyStatus=err.message;}finally{polling=false;}
    },1500);
  }
  P.partyCreate=async()=>{
    if(P.canInvite===false)throw Error('Saia da masmorra ou renasça antes de abrir uma visita.');
    if(P.peer?.role==='guest')throw Error('Volte ao seu mundo antes de convidar alguém.');
    if(role==='host'&&room&&pc){const url=new URL(location.href);url.search='?mode=personal';url.hash='visit='+room;return url.href;}
    const r=await P.rpc({op:'room-create'});if(r.status!==200)throw Error('Não foi possível criar convite');
    await connect('host',r.room);
    const url=new URL(location.href);url.search='?mode=personal';url.hash='visit='+r.room;return url.href;
  };
  P.partyJoin=async value=>{
    if(P.canInvite===false)throw Error('Saia da masmorra ou renasça antes de visitar outro mundo.');
    if(P.peer)throw Error('Feche a visita atual antes de entrar em outro mundo.');
    let id=value.trim();if(id.includes('#'))id=new URLSearchParams(id.split('#')[1]).get('visit')||'';
    if(!/^[a-f0-9-]{36}$/i.test(id))throw Error('Cole um convite válido');
    const r=await P.rpc({op:'room-join',room:id});if(r.status!==200)throw Error('Convite fechado, expirado ou mundo ocupado');
    await connect('guest',id);
  };
  P.partyClose=(notify=true)=>{
    if(notify&&room)P.rpc({op:role==='host'?'room-close':'room-send',room,message:{type:'leave'}}).catch(()=>{});
    if(opened)enqueue(10,{event:'leave',id:'guest'});
    opened=false;P.peer=null;pc?.close();pc=null;channel=null;reliable=null;room='';candidates.length=0;fragments.clear();
  };
  let partSerial=0;
  P.partySend=(code,body)=>{
    if(!opened)return;
    const c=[1,2].includes(code)?channel:reliable;
    if(!c||c.readyState!=='open'||c.bufferedAmount>262144)return;
    const raw=JSON.stringify({code,body:role==='host'&&code===2?body.body:body});
    if(raw.length<=12000)c.send(raw);
    else if(raw.length<=12000*64){const id=++partSerial,n=Math.ceil(raw.length/12000);for(let i=0;i<n;i++)c.send(JSON.stringify({fragment:id,n,i,text:raw.slice(i*12000,(i+1)*12000)}));}
  };
  setInterval(()=>{
    if(opened&&reliable?.readyState==='open'){pingTime=performance.now();reliable.send(JSON.stringify({ping:pingTime}));}
  },2000);
  P.partyOpen=()=>{
    if(P.partyModal)return;P.partyModal=true;
    const overlay=document.createElement('div');
    overlay.style.cssText='position:fixed;inset:0;z-index:20;background:#020814df;display:grid;place-items:center;padding:12px;touch-action:auto';
    const panel=document.createElement('section');panel.setAttribute('role','dialog');panel.setAttribute('aria-modal','true');panel.setAttribute('aria-label','Meu mundo e amigos');panel.style.cssText='box-sizing:border-box;width:min(460px,96vw);max-height:90dvh;overflow:auto;overscroll-behavior:contain;background:#0b2130;border:1px solid #2e7080;border-radius:16px;padding:18px;display:flex;flex-direction:column;gap:10px;touch-action:pan-y';overlay.append(panel);
    const header=document.createElement('header');header.style.cssText='display:flex;justify-content:space-between;align-items:center;gap:12px;position:sticky;top:-18px;background:#0b2130;z-index:1;padding:6px 0';panel.append(header);
    const title=document.createElement('strong');title.textContent='Meu mundo · amigos';header.append(title);
    const detail=document.createElement('p');detail.textContent='Você joga localmente e salva na nuvem em segundo plano. Um amigo pode visitar com a própria build e continuar evoluindo. PvP vale no mapa inteiro, junto dos monstros, sem prêmio por abate de jogadores.';detail.style.cssText='font-size:13px;line-height:1.5;margin:0';panel.append(detail);
    const status=document.createElement('small');panel.append(status);
    const link=document.createElement('input');link.placeholder='Cole o link do amigo';link.value=P.incoming;link.style.cssText='box-sizing:border-box;width:100%;padding:12px;font-size:16px;background:#020e19;color:#d6f5ff;border:1px solid #347082;border-radius:8px';panel.append(link);
    const qr=document.createElement('div');qr.style.cssText='display:flex;justify-content:center;background:white;align-self:center';panel.append(qr);
    const button=(label,action)=>{const b=document.createElement('button');b.textContent=label;b.style.cssText='padding:11px;font:inherit;font-size:14px;background:#123d4c;color:#d6f5ff;border:1px solid #347082;border-radius:8px;cursor:pointer';b.onclick=async()=>{b.disabled=true;try{await action();}catch(err){status.textContent=err.message;await new Promise(r=>setTimeout(r,2500));}finally{b.disabled=false;}};panel.append(b);return b;};
    button('Mostrar convite e QR Code',async()=>{link.value=await P.partyCreate();qr.replaceChildren();const code=qrcode(0,'M');code.addData(link.value);code.make();qr.innerHTML=code.createSvgTag({cellSize:4,margin:16,scalable:true});qr.firstChild.style.cssText='width:min(190px,45vw);height:auto';});
    button('Visitar esse mundo',async()=>{await P.partyJoin(link.value);});
    button('Copiar convite',async()=>{await navigator.clipboard.writeText(link.value);});
    button('Sair da visita / fechar convite',()=>{P.partyClose();P.partyStatus='Sozinho · mundo pessoal';});
    button('Baixar backup do meu mundo',P.backup);
    button('Restaurar meu save da nuvem',P.restore);
    const escape=event=>{if(event.key==='Escape')close();};
    const close=()=>{overlay.remove();P.partyModal=false;clearInterval(timer);document.removeEventListener('keydown',escape);document.getElementById('canvas')?.focus();};
    const dismiss=document.createElement('button');dismiss.textContent='×';dismiss.setAttribute('aria-label','Fechar mundo e amigos');dismiss.style.cssText='width:36px;height:36px;border:1px solid #347082;border-radius:8px;background:#123d4c;color:#d6f5ff;font-size:22px;cursor:pointer';dismiss.onclick=close;header.append(dismiss);
    button('Voltar ao jogo',close);overlay.onclick=e=>{if(e.target===overlay)close();};
    const timer=setInterval(()=>{status.textContent=P.cloud+' · '+P.partyStatus+(P.partyRTT>=0?' · '+P.partyRTT+' ms':'');},500);
    document.body.append(overlay);
    document.addEventListener('keydown',escape);
  };
})();
