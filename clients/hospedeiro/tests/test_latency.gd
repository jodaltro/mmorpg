extends TestCase

func test_ping_measures_acknowledged_input_and_expires() -> void:
	var stats := BioNetStats.new()
	stats.sent_ping("1",1000)
	stats.pong("1",1080)
	assert_eq(stats.current_ms(1080),80,"socket RTT is measured")
	stats.sent_input(7,1100)
	stats.acknowledge(7,1460)
	assert_eq(stats.current_ms(1460),360,"game RTT includes the actual acknowledgment path")
	stats.acknowledge(7,3000)
	assert_eq(stats.current_ms(3000),360,"repeated snapshot cannot inflate ping")
	assert_eq(stats.current_ms(7000),-1,"stale readings are hidden")
	stats.clear()
	assert_eq(stats.current_ms(7000),-1,"reconnect starts without a fake 0ms reading")

func test_prediction_is_immediate_and_replays_only_unacknowledged_motion() -> void:
	var prediction := BioNetPrediction.new()
	var motion := {"speed":1.0,"thrust":42.0,"maximum":7.0,"damping":3.5,"unit":48.0}
	var velocity := BioNetPrediction.velocity(Vector2.ZERO,Vector2.RIGHT,1.0/60.0,motion)
	assert_true(velocity.x>0,"movement starts without a server round trip")
	prediction.remember(1,1.0/60.0,Vector2.RIGHT)
	prediction.remember(2,1.0/60.0,Vector2.RIGHT)
	prediction.acknowledge(1)
	assert_eq(prediction.frames.size(),1,"acknowledged movement is not replayed twice")
	assert_eq(prediction.frames[0].seq,2,"newer movement remains predicted")
	for i in 1000:
		velocity=BioNetPrediction.velocity(velocity,Vector2.RIGHT,1.0/60.0,motion)
	assert_true(velocity.length()<=7.0*48.0+0.01,"prediction uses the authority's speed cap")

func test_compact_snapshot_preserves_changed_metadata_and_refreshes() -> void:
	var cache := {}
	var entity := {"id":"p","kind":"player","uid":"a","p":[1,2],"hp":100,"name":"A","genes":["g"],"traits":{"nucleo":"lobulado"}}
	var full := BioGameServer.compact_entities([entity],cache,false)
	var delta := BioGameServer.compact_entities([entity],cache,false)
	assert_true(full[0].has("traits"),"first appearance includes the body")
	assert_true(not delta[0].has("traits"),"unchanged body is not sent twenty times per second")
	assert_eq(delta[0].hp,100,"combat state is still present")
	assert_true(JSON.stringify(delta).length()<JSON.stringify(full).length(),"smaller wire payload")
	entity.name="B"
	assert_eq(BioGameServer.compact_entities([entity],cache,false)[0].name,"B","changed metadata sent immediately")
	assert_true(BioGameServer.compact_entities([entity],cache,true)[0].has("genes"),"periodic full refresh is self-contained")
	BioGameServer.compact_entities([],cache,false)
	assert_eq(cache.size(),0,"departed entities don't leak cache entries")

func test_mobile_discards_superseded_states_without_losing_body_updates_or_events() -> void:
	var old := {"seq":1,"entities":[{"id":"p","name":"A","p":[1,0],"genes":["novo"]},{"id":"gone","p":[0,0]}],"events":[{"attack":"lash"}]}
	var latest := {"seq":2,"entities":[{"id":"p","p":[2,0]}],"events":[{"ability":"teste"}],"ack":7}
	var merged := BioNetProtocol.coalesce_snapshot(old,latest)
	assert_eq(merged.entities.size(),1,"removed entities stay removed")
	assert_eq(merged.entities[0].p,[2,0],"newest position wins")
	assert_eq(merged.entities[0].genes,["novo"],"metadata in discarded state is preserved")
	assert_eq(merged.events.size(),2,"combat visuals are not lost")
	assert_eq(merged.ack,7,"newest input acknowledgment wins")
