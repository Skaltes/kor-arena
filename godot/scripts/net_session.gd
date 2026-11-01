class_name NetSession
extends Node
## Canli 1v1 baglantisi. Iki oyuncu birbirine dogrudan degil, hesap istemeyen herkese acik
## bir MQTT sunucusu uzerinden mesajlasir; bu yuzden modem ayari ve VPN gerekmez.
## Savasi yalnizca odayi acan calistirir; katilan komut yollar ve durumu izler.
## Herkese acik sunucu mesaj dusurebilir: onemli mesajlar karsi taraf onaylayana kadar her pakette tekrar yollanir.

signal joined(player_name: String, cls: String) # oda sahibi: rakip geldi
signal failed(message: String)
signal disconnected
signal status(text: String)
signal match_data(data: Dictionary)
signal state_received(data: PackedFloat32Array)
signal events_received(list: Array)
signal skill_received(id: String)
signal ready_received(cls: String)

const VERSION := 8
const BROKERS: Array[String] = [
	"wss://broker.emqx.io:8084/mqtt",
	"wss://broker.hivemq.com:8884/mqtt",
	"wss://test.mosquitto.org:8081",
]
const CODE_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" # karisan 0/O ve 1/I yok
const TOPIC := "korarena/v2/%s/%s"
const CONNECT_TIMEOUT := 6.0
const ROOM_TIMEOUT := 12.0
const SILENCE_LIMIT := 8.0
const FLUSH_EVERY := 0.1 # saniyede en cok 10 paket: sunucuyu bogmamak icin
const MAX_IN_PACKET := 12

enum Role { NONE, HOST, CLIENT }

var room_code := ""
var rtt_ms := -1 # son olculen gidis-donus gecikmesi

var _ws: WebSocketPeer
var _role := Role.NONE
var _broker := 0
var _online := false
var _greeted := false
var _buffer := PackedByteArray()
var _client_id := ""
var _hello: Array = []
var _rival_id := ""
var _matched := false
var _wait := 0.0
var _beat := 0.0
var _ping := 0.0
var _silence := 0.0
var _flush := 0.0
var _outbox: Array = []
var _out_first := 0
var _in_next := 0
var _ack_due := false
var _state := PackedFloat32Array()


func host() -> bool:
	close()
	_role = Role.HOST
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	room_code = ""
	for i in 5:
		room_code += CODE_LETTERS[rng.randi_range(0, CODE_LETTERS.length() - 1)]
	_broker = 0
	_open()
	return true


func join(code: String, player_name: String, cls: String) -> bool:
	close()
	var c := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	var broker := CODE_LETTERS.find(c.left(1))
	if c.length() != 6 or broker < 0 or broker >= BROKERS.size():
		failed.emit("Oda kodu geçersiz.")
		return false
	_role = Role.CLIENT
	_broker = broker
	room_code = c.substr(1)
	_hello = [VERSION, player_name, cls]
	_open()
	return true


func close() -> void:
	if _online:
		_send("bye", [])
	if _ws != null:
		_ws.close()
	_ws = null
	_role = Role.NONE
	_online = false
	_matched = false
	_rival_id = ""
	_buffer = PackedByteArray()
	_outbox = []
	_out_first = 0
	_in_next = 0
	_ack_due = false
	_state = PackedFloat32Array()


func _open() -> void:
	_buffer = PackedByteArray()
	_online = false
	_greeted = false
	_wait = 0.0
	_client_id = "kor%d" % (randi() % 100000000)
	_ws = WebSocketPeer.new()
	_ws.supported_protocols = PackedStringArray(["mqtt"])
	if _ws.connect_to_url(BROKERS[_broker]) != OK:
		_next_broker()


## Oda sahibi calisan ilk sunucuyu bulur; kod hangi sunucuda oldugunu da tasir.
func _next_broker() -> void:
	if _role == Role.HOST and _broker + 1 < BROKERS.size():
		_broker += 1
		_open()
		return
	var role := _role
	close()
	failed.emit("Sunucuya bağlanılamadı. İnternetini kontrol edip tekrar dene." if role == Role.HOST else "Odaya bağlanılamadı. Kodu kontrol edip tekrar dene.")


func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _greeted:
				_greeted = true
				_mqtt_connect()
			while _ws != null and _ws.get_available_packet_count() > 0:
				_buffer.append_array(_ws.get_packet())
				_read_packets()
		WebSocketPeer.STATE_CLOSED:
			if _online:
				_lost()
			else:
				_next_broker()
			return
	if _ws == null:
		return
	_wait += delta
	if not _online:
		if _wait > CONNECT_TIMEOUT:
			_next_broker()
		return
	_ping += delta
	if _ping > 20.0: # sunucu baglantiyi kapatmasin
		_ping = 0.0
		_ws.send(PackedByteArray([0xC0, 0]))
	_tick_session(delta)


func _tick_session(delta: float) -> void:
	_beat += delta
	if _role == Role.CLIENT and not _matched:
		if _wait > ROOM_TIMEOUT:
			close()
			failed.emit("Oda bulunamadı. Kodu ve arkadaşının odayı açık tuttuğunu kontrol et.")
		elif _beat > 1.0:
			_beat = 0.0
			_send("hello", [_client_id] + _hello)
		return
	if not _matched:
		return
	if _beat > 1.0:
		_beat = 0.0
		_send("ping", [Time.get_ticks_msec()])
	_flush += delta
	if _flush >= FLUSH_EVERY:
		_flush = 0.0
		_send_packet()
	_silence += delta
	if _silence > SILENCE_LIMIT:
		_lost()


func _lost() -> void:
	close()
	disconnected.emit()


# ---- MQTT 3.1.1: yalnizca gereken en kucuk parcasi ----

func _text(s: String) -> PackedByteArray:
	var b := s.to_utf8_buffer()
	var out := PackedByteArray([b.size() >> 8, b.size() & 255])
	out.append_array(b)
	return out


func _frame(head: int, body: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([head])
	var n := body.size()
	while true:
		var d := n % 128
		n /= 128
		out.append(d | 128 if n > 0 else d)
		if n == 0:
			break
	out.append_array(body)
	return out


func _mqtt_connect() -> void:
	var body := _text("MQTT")
	body.append_array(PackedByteArray([4, 2, 0, 60])) # temiz oturum, 60 sn canli tutma
	body.append_array(_text(_client_id))
	_ws.send(_frame(0x10, body))


func _subscribe(topic: String) -> void:
	var body := PackedByteArray([0, 1])
	body.append_array(_text(topic))
	body.append(0)
	_ws.send(_frame(0x82, body))


func _publish(topic: String, payload: PackedByteArray) -> void:
	var body := _text(topic)
	body.append_array(payload)
	_ws.send(_frame(0x30, body))


func _read_packets() -> void:
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
			_on_connack(body)
		elif kind == 0x30:
			var skip := 2 + (body[0] << 8 | body[1])
			_on_message(body.slice(skip))
		if _ws == null:
			return


func _on_connack(body: PackedByteArray) -> void:
	if body.size() < 2 or body[1] != 0:
		_next_broker()
		return
	_online = true
	_wait = 0.0
	_beat = 2.0
	_silence = 0.0
	_subscribe(TOPIC % [room_code, "c2h" if _role == Role.HOST else "h2c"])
	if _role == Role.HOST:
		status.emit("ODA KODU: %s%s" % [CODE_LETTERS[_broker], room_code])


func _send(kind: String, args: Array) -> void:
	if not _online or _ws == null:
		return
	_publish(TOPIC % [room_code, "h2c" if _role == Role.HOST else "c2h"], var_to_bytes([kind, args]))


func _on_message(payload: PackedByteArray) -> void:
	var msg: Variant = bytes_to_var(payload) # nesne tasiyamaz, yalnizca duz veri
	if not (msg is Array) or msg.size() != 2 or not (msg[0] is String) or not (msg[1] is Array):
		return
	_silence = 0.0
	var a: Array = msg[1]
	match msg[0]:
		"hello":
			if _role == Role.HOST and a.size() == 4 and a[1] == VERSION and GameData.CLASSES.has(a[3]):
				if _rival_id == "":
					_rival_id = a[0]
					_matched = true
					joined.emit(String(a[2]).left(16), a[3])
		"pack":
			if a.size() == 4 and a[0] is int and a[1] is int and a[2] is Array:
				_on_pack(a[0], a[1], a[2], a[3])
		"ping":
			_send("pong", a)
		"pong":
			if a.size() == 1 and a[0] is int:
				rtt_ms = Time.get_ticks_msec() - a[0]
		"bye":
			if _matched:
				_lost()


func _on_pack(ack: int, first: int, items: Array, state: Variant) -> void:
	while _out_first < ack and not _outbox.is_empty():
		_outbox.pop_front()
		_out_first += 1
	for i in items.size():
		if first + i == _in_next:
			_in_next += 1
			_ack_due = true
			_deliver(items[i])
			if _ws == null:
				return
	if not items.is_empty():
		_ack_due = true
	if _role == Role.CLIENT and state is PackedFloat32Array and not state.is_empty():
		state_received.emit(state)


func _deliver(item: Variant) -> void:
	if not (item is Array) or item.size() != 2:
		return
	var value: Variant = item[1]
	match item[0]:
		"match":
			if _role == Role.CLIENT and value is Dictionary:
				_matched = true
				_silence = 0.0
				match_data.emit(value)
		"events":
			if _role == Role.CLIENT and value is Array:
				events_received.emit(value)
		"skill":
			if _role == Role.HOST and value is String:
				skill_received.emit(value)
		"ready":
			if value is String and GameData.CLASSES.has(value):
				ready_received.emit(value)


## Tek pakette: onay + onaylanmamis mesajlar + oda sahibinin son savas durumu.
func _send_packet() -> void:
	if _outbox.is_empty() and _state.is_empty() and not _ack_due:
		return
	_send("pack", [_in_next, _out_first, _outbox.slice(0, MAX_IN_PACKET), _state])
	_state = PackedFloat32Array()
	_ack_due = false


func _reliable(kind: String, value: Variant) -> void:
	_outbox.append([kind, value])


func send_match(data: Dictionary) -> void:
	_reliable("match", data)


func send_state(data: PackedFloat32Array) -> void:
	_state = data


func send_events(list: Array) -> void:
	_reliable("events", list)


func send_skill(id: String) -> void:
	_reliable("skill", id)


func send_ready(cls: String) -> void:
	_reliable("ready", cls)