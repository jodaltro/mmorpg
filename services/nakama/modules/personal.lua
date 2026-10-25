-- Private, unranked saves and WebRTC signalling. Never calls the MMORPG engine.
local nk = require('nakama')
local SYSTEM = '00000000-0000-0000-0000-000000000000'
local function read(collection, key, owner)
  local rows = nk.storage_read({{collection=collection,key=key,user_id=owner}})
  return rows[1]
end
local function write(collection, key, owner, value, version)
  return nk.storage_write({{collection=collection,key=key,user_id=owner,value=value,
    version=version or '*',permission_read=0,permission_write=0}})
end
local function rpc(ctx, raw)
  if not ctx.user_id or ctx.user_id == '' then error('session required') end
  if #raw > 524288 then error('payload too large') end
  local p = nk.json_decode(raw)
  local uid = ctx.user_id
  if p.op == 'load' then
    local meta = read('personal_meta_v1','world',uid)
    local offset = math.max(0, math.floor(tonumber(p.offset) or 0))
    local segment = read('personal_journal_v1',tostring(offset),uid)
    local definition = offset == 0 and read('personal_definition_v1','world',uid) or nil
    return nk.json_encode({status=200,definition=definition and definition.value or nil,meta=meta and meta.value or {count=0},
      version=meta and meta.version or '*',segment=segment and segment.value or {commands={}}})
  elseif p.op == 'save' then
    if type(p.commands) ~= 'table' or #p.commands > 128 or #p.commands == 0 then error('invalid batch') end
    local meta = read('personal_meta_v1','world',uid)
    local count = meta and meta.value.count or 0
    local hash = nk.sha256_hash(nk.json_encode(p.commands))
    if meta and meta.value.request == p.request then
      return nk.json_encode({status=meta.value.batch_hash == hash and 200 or 409,count=count,version=meta.version})
    end
    if p.base ~= count or p.version ~= (meta and meta.version or '*') then return nk.json_encode({status=409,count=count}) end
    local value = {count=count+#p.commands,request=p.request,batch_hash=hash,player=p.player,identity=p.identity,universe=p.universe,updated=nk.time()}
    local writes = {
      {collection='personal_journal_v1',key=tostring(count),user_id=uid,value={commands=p.commands},version='*',permission_read=0,permission_write=0},
      {collection='personal_meta_v1',key='world',user_id=uid,value=value,version=p.version,permission_read=0,permission_write=0}}
    if count == 0 then
      if type(p.definition) ~= 'string' and type(p.definition) ~= 'table' then error('universe required') end
      -- Preserve JSON syntax, including the distinction between [] and {} across Lua.
      local definition = type(p.definition) == 'string' and {json=p.definition} or p.definition
      table.insert(writes,{collection='personal_definition_v1',key='world',user_id=uid,value=definition,version='*',permission_read=0,permission_write=0})
    end
    local ok, result = pcall(nk.storage_write, writes)
    if not ok then return nk.json_encode({status=409}) end
    for _,ack in ipairs(result) do
      if ack.collection == 'personal_meta_v1' and ack.key == 'world' then
        return nk.json_encode({status=200,count=value.count,version=ack.version})
      end
    end
    error('missing save receipt')
  end
  if p.op == 'room-create' then
    local id = nk.uuid_v4()
    write('personal_rooms_v1',id,SYSTEM,{owner=uid,expires=nk.time()+900000,seq=0,messages={}})
    return nk.json_encode({status=200,room=id,role='host'})
  end
  if type(p.room) ~= 'string' or not p.room:match('^[%x%-]+$') or #p.room ~= 36 then error('invalid room') end
  for _=1,3 do
    local row = read('personal_rooms_v1',p.room,SYSTEM)
    if not row or row.value.expires < nk.time() then return nk.json_encode({status=410}) end
    local room = row.value
    local role = uid == room.owner and 'host' or 'guest'
    if p.op == 'room-join' then
      if uid == room.owner then return nk.json_encode({status=409}) end
      if room.guest and room.guest ~= uid then return nk.json_encode({status=403}) end
      room.guest = uid
    elseif uid ~= room.owner and uid ~= room.guest then return nk.json_encode({status=403}) end
    if p.op == 'room-close' then
      if role ~= 'host' then return nk.json_encode({status=403}) end
      room.expires = 0
    elseif p.op == 'room-send' then
      if type(p.message) ~= 'table' or #nk.json_encode(p.message) > 32768 then error('invalid signal') end
      if not ({description=true,candidate=true,leave=true})[p.message.type] then error('signal only') end
      room.seq = room.seq + 1
      table.insert(room.messages,{seq=room.seq,from=role,body=p.message})
      while #room.messages > 160 do table.remove(room.messages,1) end
    elseif p.op ~= 'room-poll' and p.op ~= 'room-join' then error('unsupported operation') end
    if p.op ~= 'room-close' then room.expires = nk.time()+900000 end
    local ok = pcall(write,'personal_rooms_v1',p.room,SYSTEM,room,row.version)
    if ok then
      local messages = {}
      for _,m in ipairs(room.messages) do if m.seq > (tonumber(p.after) or 0) and m.from ~= role then table.insert(messages,m) end end
      return nk.json_encode({status=200,role=role,guest=room.guest ~= nil,messages=messages,seq=room.seq})
    end
  end
  return nk.json_encode({status=409})
end
nk.register_rpc(rpc,'hosp_personal')
return true
