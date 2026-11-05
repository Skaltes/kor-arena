extends SceneTree
## Herkese acik sunucularin gercek gecikmesi: kendine yolladigi mesajin donus suresini olcer.
## Calistirma: Godot --headless --path . --script res://tests/test_broker.gd

const RATES := [15.0, 8.0]
const SECONDS := 12.0

var _net := NetSession.new()
var _ws: WebSocketPeer
var _buffer := PackedByteArray()
var _topic := ""
var _delays: Array[int] = []
var _ready := false


func _send_connect() -> void:
	var body := _net._text("MQTT")
	body.append_array(PackedByteArray([4, 2, 0, 60]))
	body.append_array(_net._text("korolcum%d" % (randi() % 100000000)))
	_ws.send(_net._frame(0x10, body))


func _pump() -> void:
	_ws.poll()
	while _ws.get_available_packet_count() > 0:
		_buffer.append_array(_ws.get_packet())
	while _buffer.size() >= 2:
		var mult := 1
		var length := 0
		var i := 1
		var done := false
		while i < _buffer.size() and i <= 4:
			var d := _buffer[i]
			length += (d & 127) * mult
			mult *= 128
			i += 1
			if d < 128:
				done = true
				break
		if not done or _buffer.size() < i + length:
			return
		var kind := _buffer[0] & 0xF0
		var body := _buffer.slice(i, i + length)
		_buffer = _buffer.slice(i + length)
		if kind == 0x20:
			var sub := PackedByteArray([0, 1])
			sub.append_array(_net._text(_topic))
			sub.append(0)
			_ws.send(_net._frame(0x82, sub))
		elif kind == 0x90:
			_ready = true
		elif kind == 0x30:
			var skip := 2 + (body[0] << 8 | body[1])
			var text := body.slice(skip).get_string_from_ascii()
			_delays.append(Time.get_ticks_msec() - text.to_int())


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		_pump()
		await process_frame


func _measure(url: String, rate: float) -> void:
	_ws = WebSocketPeer.new()
	_ws.supported_protocols = PackedStringArray(["mqtt"])
	_buffer = PackedByteArray()
	_delays = []
	_ready = false
	_topic = "korarena/olcum/%d" % (randi() % 100000000)
	var begin := Time.get_ticks_msec()
	_ws.connect_to_url(url)
	while _ws.get_ready_state() != WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - begin < 8000:
		_ws.poll()
		await process_frame
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("%s: BAGLANAMADI" % url)
		return
	var connect_ms := Time.get_ticks_msec() - begin
	_send_connect()
	while not _ready and Time.get_ticks_msec() - begin < 12000:
		_pump()
		await process_frame
	var sent := 0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < SECONDS * 1000.0:
		_pump()
		if (Time.get_ticks_msec() - start) * rate / 1000.0 > sent:
			sent += 1
			var body := _net._text(_topic)
			body.append_array(("%d|" % Time.get_ticks_msec()).rpad(190, ".").to_ascii_buffer())
			_ws.send(_net._frame(0x30, body))
		await process_frame
	await _wait(2.0)
	_delays.sort()
	var n := _delays.size()
	print("%s %.0f/sn: baglanti %d ms, gelen %d/%d, orta %d ms, %%95 %d ms, en kotu %d ms" % [url, rate, connect_ms, n, sent,
		_delays[n / 2] if n > 0 else -1, _delays[int(n * 0.95)] if n > 0 else -1, _delays[-1] if n > 0 else -1])
	_ws.close()


func _initialize() -> void:
	_run()


func _run() -> void:
	for url: String in NetSession.BROKERS:
		for rate: float in RATES:
			await _measure(url, rate)
	_net.free()
	quit()
