class_name AccountService
extends Node
## Account service for the launcher (server, UDP 7778): raw ENet packets with
## a JSON body, no game protocol, so the launcher (a separate project) can
## create an account or check a login before starting the game.
##   request  {"op": "register" | "login", "user": "...", "auth": "<sha256>"}
##   response {"ok": bool, "error": "...", "user": "..."}

var _host: ENetConnection
var _store := AccountStore.new()


func start(port: int) -> Error:
	_host = ENetConnection.new()
	var err: Error = _host.create_host_bound("*", port, 64, 1)
	if err == OK:
		print("[accounts] listening on UDP %d" % port)
	return err


func _process(_delta: float) -> void:
	if _host == null:
		return
	while true:
		var event: Array = _host.service(0)
		if event[0] == ENetConnection.EVENT_NONE or event[0] == ENetConnection.EVENT_ERROR:
			break
		if event[0] == ENetConnection.EVENT_RECEIVE:
			var peer: ENetPacketPeer = event[1]
			var reply: Dictionary = handle(JSON.parse_string(peer.get_packet().get_string_from_utf8()))
			peer.send(0, JSON.stringify(reply).to_utf8_buffer(), ENetPacketPeer.FLAG_RELIABLE)


func handle(request: Variant) -> Dictionary:
	if not request is Dictionary:
		return {"ok": false, "error": "BAD_REQUEST"}
	var user: String = AccountStore.normalize(str(request.get("user", "")))
	var auth: String = str(request.get("auth", ""))
	match str(request.get("op", "")):
		"register":
			var err: String = _store.register(user, auth)
			print("[accounts] register %s: %s" % [user, err if err != "" else "ok"])
			return {"ok": err == "", "error": err, "user": user}
		"login":
			var ok: bool = _store.verify(user, auth)
			return {"ok": ok, "error": "" if ok else "BAD_LOGIN", "user": user}
	return {"ok": false, "error": "BAD_REQUEST"}
