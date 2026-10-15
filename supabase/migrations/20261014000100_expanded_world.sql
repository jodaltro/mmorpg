-- Additive expansion. Existing characters, facts, saves and the 05A demonstration remain valid.
alter table game.worlds add column ruleset text not null default 'forest-demo-v1' check(ruleset in ('forest-demo-v1','expanded-v1'));
alter table game.character_equipment drop constraint character_equipment_slot_check;
alter table game.character_equipment add constraint character_equipment_slot_check check(slot in ('weapon','armor','charm','tool','cloak'));
alter table game.character_opportunities drop constraint character_opportunities_status_check;
alter table game.character_opportunities add constraint character_opportunities_status_check check(status in ('available','started','completed','expired','closed','ignored','pending','cancelled'));
alter table game.content_definitions drop constraint content_definitions_kind_check;
alter table game.content_definitions add constraint content_definitions_kind_check check(kind in ('item','ability','opportunity','creature','npc','event','region','node'));

create table game.journey_runtime (
 character_id uuid primary key references game.characters(id), version integer not null default 1 check(version>0),
 step bigint not null default 0 check(step>=0), poison integer not null default 0 check(poison between 0 and 3)
);
create table game.journey_cooldowns (
 character_id uuid not null references game.characters(id), ability_id text not null,
 due_step bigint not null check(due_step>=0), primary key(character_id,ability_id),
 foreign key(character_id,ability_id) references game.character_abilities(character_id,ability_id)
);
create table game.journey_schedules (
 character_id uuid not null references game.characters(id), opportunity_id text not null,
 due_step bigint not null check(due_step>=0), primary key(character_id,opportunity_id),
 foreign key(character_id,opportunity_id) references game.character_opportunities(character_id,opportunity_id)
);
create table game.journey_encounters (
 character_id uuid primary key references game.characters(id), creature text not null,
 hp integer not null check(hp between 0 and 200), turn integer not null check(turn>=0),
 phase text not null check(phase in ('ready','preparing','exposed','hidden','defeated','escaped')),
 range integer not null check(range between 0 and 2), fractured boolean not null, marked boolean not null,
 burn integer not null check(burn between 0 and 3), defended integer not null check(defended>=0), collected boolean not null
);
do $$ declare t text;begin
 foreach t in array array['journey_runtime','journey_cooldowns','journey_schedules','journey_encounters'] loop
  execute format('alter table game.%I enable row level security',t);
  execute format('alter table game.%I force row level security',t);
  execute format('create policy owner_scope on game.%I to game_backend using(character_id in(select id from game.characters)) with check(character_id in(select id from game.characters))',t);
  execute format('grant select,insert,update,delete on game.%I to game_backend',t);
 end loop;
end $$;
revoke all on all tables in schema game from public,anon,authenticated,service_role;
