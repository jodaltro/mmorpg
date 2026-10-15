-- A scheduled, sourced world event may complete after its author has travelled.
-- Permit the backend's regional projection update only with an owned character
-- currently present OR that character's immutable authored event in that region.
drop policy region_update on game.world_regions;
create policy region_update on game.world_regions for update to game_backend
 using(exists(select 1 from game.characters c where c.world_id=world_regions.world_id and
  (c.region_id=world_regions.id or exists(select 1 from game.world_events e where e.author_character_id=c.id and e.world_id=world_regions.world_id and e.region_id=world_regions.id))))
 with check(exists(select 1 from game.characters c where c.world_id=world_regions.world_id and
  (c.region_id=world_regions.id or exists(select 1 from game.world_events e where e.author_character_id=c.id and e.world_id=world_regions.world_id and e.region_id=world_regions.id))));
