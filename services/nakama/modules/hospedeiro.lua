local nk = require('nakama')
local M = {}
local LABEL = 'hospedeiro-v1'
local function host(ctx, key)
  return ctx.env.HOSPEDEIRO_GAME_KEY and #ctx.env.HOSPEDEIRO_GAME_KEY >= 32 and key == ctx.env.HOSPEDEIRO_GAME_KEY
end
local function decode(raw)
  local ok, value = pcall(nk.json_decode, raw or '{}')
  if not ok or type(value) ~= 'table' then error('invalid payload') end
  return value
end
local function lobby(ctx, raw)
  local p = decode(raw)
  local matches = nk.match_list(1, true, LABEL, nil, nil, nil)
  if #matches > 0 then return nk.json_encode({match_id = matches[1].match_id}) end
  if not host(ctx, p.host_key) then error('O servidor de jogo esta iniciando. Tente novamente.') end
  return nk.json_encode({match_id = nk.match_create('hospedeiro', {})})
end
-- Only player intentions cross this RPC. Actor and adapter credential come from the server.
local function world(ctx, raw)
  local p = decode(raw)
  local id = 'nk-' .. ctx.user_id
  local method, path, body = 'get', '', nil
  if p.op == 'view' then path = '/v1/views/' .. id .. '?limit=30'
  elseif p.op == 'affordances' then path = '/v1/affordances/' .. id
  elseif p.op == 'command' then
    body = p.body or {}
    if body.origin ~= 'player' or not ({act=true,accept=true,decline=true,abandon=true})[body.kind] then error('player intentions only') end
    -- Explicit fields: never forward caller-supplied origin, actor or revision guards.
    body = {version=1, requestId=id .. ':' .. nk.uuid_v4(), origin='player', actor=id,
      kind=body.kind, action=body.action, args=body.args, quest=body.quest}
    method, path = 'post', '/v1/commands'
  elseif p.op == 'reset' then
    if p.confirm ~= 'new-world' then error('confirmation required') end
    method, path, body = 'post', '/v1/world/reset', {version=1,player=id,confirm='new-world'}
  else error('unsupported operation') end
  local headers = {['Content-Type']='application/json', ['X-Adapter-Key']=ctx.env.HOSPEDEIRO_ADAPTER_KEY,
    ['X-Edge-Secret']=ctx.env.HOSPEDEIRO_EDGE_SECRET or ''}
  local code, _, response = nk.http_request(ctx.env.HOSPEDEIRO_ENGINE_URL .. path, method, headers,
    body and nk.json_encode(body) or '', 5000)
  return nk.json_encode({status=code, body=decode(response)})
end
function M.match_init(ctx, params)
  return {players={}, host=nil, last={}, names={}, host_tick=0}, 20, LABEL
end
function M.match_join_attempt(ctx, dispatcher, tick, state, presence, metadata)
  if host(ctx, metadata.host_key) then
    if state.host and state.host.session_id ~= presence.session_id then return state, false, 'server already connected' end
    return state, true
  end
  if not state.host or tick-state.host_tick > 200 then return state, false, 'server unavailable' end
  local count=0
  for _, _ in pairs(state.players) do count=count+1 end
  if count >= 64 then return state, false, 'body full' end
  for _, p in pairs(state.players) do
    if p.user_id == presence.user_id then return state, false, 'cell already connected' end
  end
  return state, true
end
local function send(dispatcher, code, data, targets)
  if targets and #targets == 0 then return end
  dispatcher.broadcast_message(code, nk.json_encode(data), targets, nil, true)
end
function M.match_join(ctx, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    -- Host role is granted in join_attempt, recorded by a separate signal below.
    if state.pending_host == p.session_id then
      state.host=p; state.host_tick=tick; state.pending_host=nil
      for sid, player in pairs(state.players) do send(dispatcher, 10, {event='join',id=player.user_id,name=state.names[sid] or player.username}, {p}) end
    else
      state.players[p.session_id]=p
      if state.host then send(dispatcher, 10, {event='join',id=p.user_id,name=state.names[p.session_id] or p.username}, {state.host}) end
    end
  end
  return state
end
local join_attempt = M.match_join_attempt
function M.match_join_attempt(ctx, dispatcher, tick, state, presence, metadata)
  local s, allowed, reason = join_attempt(ctx, dispatcher, tick, state, presence, metadata)
  if allowed and host(ctx, metadata.host_key) then s.pending_host=presence.session_id end
  if allowed then s.names[presence.session_id]=string.sub(string.gsub(metadata.name or presence.username,'%c',''),1,96) end
  return s, allowed, reason or ''
end
function M.match_leave(ctx, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    if state.host and p.session_id == state.host.session_id then state.host=nil
    else
      state.players[p.session_id]=nil; state.last[p.session_id]=nil; state.names[p.session_id]=nil
      if state.host then send(dispatcher,10,{event='leave',id=p.user_id},{state.host}) end
    end
  end
  return state
end
function M.match_loop(ctx, dispatcher, tick, state, messages)
  for _, msg in ipairs(messages) do
    if state.host and msg.sender.session_id == state.host.session_id then
      state.host_tick=tick
      if msg.op_code == 2 and #msg.data < 240000 then
        local ok, packet = pcall(nk.json_decode,msg.data)
        if ok and type(packet)=='table' and type(packet.target)=='string' then
          for _, p in pairs(state.players) do
            if p.user_id==packet.target then send(dispatcher,2,packet.body,{p}); break end
          end
        end
      end
    elseif msg.op_code == 1 and state.host and state.players[msg.sender.session_id] and #msg.data <= 2048 then
      local budget=state.last[msg.sender.session_id]
      if not budget or budget.tick~=tick then budget={tick=tick,count=0};state.last[msg.sender.session_id]=budget end
      if budget.count < 3 then
        budget.count=budget.count+1
        local ok, input=pcall(nk.json_decode,msg.data)
        if ok and type(input)=='table' then send(dispatcher,1,{id=msg.sender.user_id,input=input},{state.host}) end
      end
    end
  end
  return state
end
function M.match_terminate(ctx, dispatcher, tick, state, grace) return state end
function M.match_signal(ctx, dispatcher, tick, state, data) return state, '' end
nk.register_rpc(lobby, 'hosp_lobby')
nk.register_rpc(world, 'hosp_world')
return M
