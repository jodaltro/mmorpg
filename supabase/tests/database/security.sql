-- Run through `supabase test db` on the LOCAL stack only. All assertions roll back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);
select ok(not has_schema_privilege('anon','game','USAGE'),'anon cannot access internal schema');
select ok(not has_schema_privilege('authenticated','game','USAGE'),'authenticated cannot access internal schema');
select ok(not has_schema_privilege('service_role','game','USAGE'),'Data API service role has no internal grants');
select ok(not has_table_privilege('authenticated','game.character_inventory','UPDATE'),'player cannot update inventory');
select ok(not has_table_privilege('authenticated','game.character_abilities','INSERT'),'player cannot grant abilities');
select ok(not has_table_privilege('authenticated','game.world_events','INSERT'),'player cannot create historical events');
select ok(not has_table_privilege('authenticated','game.npc_relationships','UPDATE'),'player cannot change NPC relationships');
select ok((select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='game' and c.relkind='r'),'RLS forced on every internal table');
select * from finish();
rollback;
