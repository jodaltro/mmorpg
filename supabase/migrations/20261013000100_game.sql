-- Internal schema is deliberately absent from Data API exposed schemas.
create schema game;
revoke all on schema game from public, anon, authenticated, service_role;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'game_backend') then
    create role game_backend nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
  end if;
end $$;
grant usage on schema game to game_backend;

create table game.worlds (
  id text primary key, version integer not null default 1 check(version > 0),
  name text not null, is_test boolean not null default false, created_at timestamptz not null default now()
);
create table game.world_regions (
  world_id text not null references game.worlds(id), id text not null,
  version integer not null default 1 check(version > 0), name text not null,
  threat boolean not null default true, notice_published boolean not null default false,
  primary key(world_id,id)
);
create table game.content_definitions (
  kind text not null check(kind in ('item','ability','opportunity','creature','npc','event')),
  id text not null, version integer not null check(version > 0), definition jsonb not null check(jsonb_typeof(definition)='object'),
  primary key(kind,id)
);
create table game.characters (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id),
  world_id text not null, region_id text not null, name text not null check(length(name) between 1 and 40),
  revision bigint not null default 0 check(revision >= 0), hp integer not null default 100 check(hp between 0 and 100),
  provenance text not null default 'server' check(provenance in ('server','offline-import')),
  created_at timestamptz not null default now(), foreign key(world_id,region_id) references game.world_regions(world_id,id),
  unique(id,world_id)
);
create index characters_owner_world on game.characters(owner_id,world_id);
create table game.character_facts (
  id uuid primary key default gen_random_uuid(), character_id uuid not null references game.characters(id),
  version integer not null default 1 check(version > 0), kind text not null, semantic_key text not null,
  payload jsonb not null default '{}' check(jsonb_typeof(payload)='object'), created_at timestamptz not null default now(),
  unique(character_id,semantic_key), unique(id,character_id)
);
create index character_facts_kind on game.character_facts(character_id,kind);
create table game.character_memories (
  character_id uuid not null references game.characters(id), id text not null,
  version integer not null default 1 check(version > 0), fact_id uuid not null,
  description text not null, primary key(character_id,id),
  foreign key(fact_id,character_id) references game.character_facts(id,character_id)
);
create table game.character_abilities (
  character_id uuid not null references game.characters(id), ability_id text not null,
  definition_kind text not null default 'ability' check(definition_kind='ability'),
  version integer not null default 1 check(version > 0), source_fact_id uuid not null,
  primary key(character_id,ability_id), foreign key(definition_kind,ability_id) references game.content_definitions(kind,id),
  foreign key(source_fact_id,character_id) references game.character_facts(id,character_id)
);
create table game.character_inventory (
  character_id uuid not null references game.characters(id), item_id text not null,
  definition_kind text not null default 'item' check(definition_kind='item'),
  version integer not null default 1 check(version > 0), quantity integer not null check(quantity between 1 and 1000000),
  primary key(character_id,item_id), foreign key(definition_kind,item_id) references game.content_definitions(kind,id)
);
create table game.character_equipment (
  character_id uuid not null references game.characters(id), slot text not null check(slot in ('weapon','armor','charm')),
  item_id text not null, version integer not null default 1 check(version > 0), primary key(character_id,slot),
  foreign key(character_id,item_id) references game.character_inventory(character_id,item_id)
);
create table game.character_opportunities (
  character_id uuid not null references game.characters(id), opportunity_id text not null,
  definition_kind text not null default 'opportunity' check(definition_kind='opportunity'),
  version integer not null default 1 check(version > 0), status text not null check(status in ('available','started','completed','expired','closed')),
  source_fact_id uuid not null, expires_at timestamptz,
  primary key(character_id,opportunity_id), foreign key(definition_kind,opportunity_id) references game.content_definitions(kind,id),
  foreign key(source_fact_id,character_id) references game.character_facts(id,character_id)
);
-- NPC knowledge/relations are private perspectives of each character, not globally omniscient NPC state.
create table game.npc_knowledge (
  character_id uuid not null references game.characters(id), npc_id text not null, fact_id uuid not null,
  definition_kind text not null default 'npc' check(definition_kind='npc'),
  version integer not null default 1 check(version > 0), source text not null check(source in ('conversation','delivery','observation','offline-import')),
  primary key(character_id,npc_id,fact_id), foreign key(fact_id,character_id) references game.character_facts(id,character_id),
  foreign key(definition_kind,npc_id) references game.content_definitions(kind,id)
);
create table game.npc_relationships (
  character_id uuid not null references game.characters(id), npc_id text not null,
  definition_kind text not null default 'npc' check(definition_kind='npc'),
  version integer not null default 1 check(version > 0), trust integer not null default 0 check(trust between -100 and 100),
  primary key(character_id,npc_id), foreign key(definition_kind,npc_id) references game.content_definitions(kind,id)
);
create table game.world_events (
  id uuid primary key default gen_random_uuid(), world_id text not null, region_id text not null,
  definition_id text not null, version integer not null default 1 check(version > 0),
  definition_kind text not null default 'event' check(definition_kind='event'),
  author_character_id uuid not null, payload jsonb not null default '{}' check(jsonb_typeof(payload)='object'),
  created_at timestamptz not null default now(), unique(world_id,definition_id),
  foreign key(world_id,region_id) references game.world_regions(world_id,id),
  foreign key(author_character_id,world_id) references game.characters(id,world_id),
  foreign key(definition_kind,definition_id) references game.content_definitions(kind,id)
);
create table game.scheduled_consequences (
  id uuid primary key default gen_random_uuid(), character_id uuid not null references game.characters(id),
  world_id text not null, region_id text not null, action_id text not null,
  version integer not null default 1 check(version > 0), source_fact_id uuid not null,
  due_at timestamptz not null, status text not null default 'pending' check(status in ('pending','executed','cancelled')),
  unique(character_id,action_id), foreign key(world_id,region_id) references game.world_regions(world_id,id),
  foreign key(source_fact_id,character_id) references game.character_facts(id,character_id),
  foreign key(character_id,world_id) references game.characters(id,world_id)
);
create index scheduled_due on game.scheduled_consequences(due_at,id) where status='pending';
create table game.decision_records (
  id uuid primary key default gen_random_uuid(), character_id uuid not null references game.characters(id),
  evaluation_id text not null, version integer not null default 1 check(version > 0), revision bigint not null check(revision >= 0),
  policy_id text not null, selected_id text not null, candidates jsonb not null check(jsonb_typeof(candidates)='array'),
  provider text not null, metadata jsonb not null default '{}', created_at timestamptz not null default now(),
  unique(character_id,evaluation_id,policy_id)
);
create table game.event_outbox (
  id uuid primary key default gen_random_uuid(), character_id uuid not null references game.characters(id),
  fact_id uuid not null unique, version integer not null default 1 check(version > 0), topic text not null,
  payload jsonb not null check(jsonb_typeof(payload)='object'), created_at timestamptz not null default now(), delivered_at timestamptz,
  foreign key(fact_id,character_id) references game.character_facts(id,character_id)
);
create index outbox_pending on game.event_outbox(created_at,id) where delivered_at is null;
create table game.encounters (
  id uuid primary key default gen_random_uuid(), character_id uuid not null references game.characters(id),
  creature_id text not null default 'corrupted-wolf', version integer not null default 1 check(version > 0),
  hp integer not null default 60 check(hp between 0 and 60), turn integer not null default 0 check(turn >= 0),
  phase text not null default 'ready' check(phase in ('ready','preparing','exposed','defeated')),
  collected boolean not null default false, unique(character_id,creature_id), unique(id,character_id)
);
create table game.command_receipts (
  character_id uuid not null references game.characters(id), request_id uuid not null,
  version integer not null default 1 check(version > 0), fingerprint text not null,
  response jsonb not null check(jsonb_typeof(response)='object'), primary key(character_id,request_id)
);
create table game.development_imports (
  character_id uuid primary key references game.characters(id), version integer not null default 1 check(version=1),
  source_version integer not null check(source_version in (1,2,3)), source_checksum text not null,
  manifest_fingerprint text not null,
  source_actor text not null, source_world text not null, imported_at timestamptz not null default now(),
  unique(character_id,source_checksum)
);

-- Only the server DB role has schema access. Even a Data API configuration mistake leaves anon/authenticated denied.
do $$ declare t record; begin
  for t in select tablename from pg_tables where schemaname='game' loop
    execute format('alter table game.%I enable row level security',t.tablename);
    execute format('alter table game.%I force row level security',t.tablename);
  end loop;
end $$;
create policy character_owner on game.characters to game_backend
  using(owner_id=nullif(current_setting('app.user_id',true),'')::uuid)
  with check(owner_id=nullif(current_setting('app.user_id',true),'')::uuid);
do $$ declare t text; begin
  foreach t in array array['character_facts','character_memories','character_abilities','character_inventory','character_equipment','character_opportunities','npc_knowledge','npc_relationships','scheduled_consequences','decision_records','event_outbox','encounters','command_receipts','development_imports'] loop
    execute format('create policy owner_scope on game.%I to game_backend using(character_id in (select id from game.characters)) with check(character_id in (select id from game.characters))',t);
  end loop;
end $$;
create policy world_read on game.worlds for select to game_backend using(true);
create policy region_read on game.world_regions for select to game_backend using(true);
create policy region_update on game.world_regions for update to game_backend
  using(exists(select 1 from game.characters c where c.world_id=world_regions.world_id and c.region_id=world_regions.id))
  with check(exists(select 1 from game.characters c where c.world_id=world_regions.world_id and c.region_id=world_regions.id));
create policy definitions_read on game.content_definitions for select to game_backend using(true);
create policy world_event_read on game.world_events for select to game_backend using(true);
create policy world_event_write on game.world_events for insert to game_backend
  with check(author_character_id in (select id from game.characters where world_id=world_events.world_id));
grant select on game.worlds,game.content_definitions to game_backend;
grant select,update on game.world_regions to game_backend;
grant select,insert on game.world_events to game_backend;
grant select,insert,update on game.characters,game.character_inventory,game.character_equipment,game.character_opportunities,game.npc_relationships,game.scheduled_consequences,game.encounters to game_backend;
grant delete on game.character_inventory,game.character_equipment to game_backend;
grant select,insert on game.character_facts,game.character_memories,game.character_abilities,game.npc_knowledge,game.decision_records,game.event_outbox,game.command_receipts,game.development_imports to game_backend;
revoke all on all tables in schema game from public,anon,authenticated,service_role;
alter default privileges in schema game revoke all on tables from public,anon,authenticated,service_role;
