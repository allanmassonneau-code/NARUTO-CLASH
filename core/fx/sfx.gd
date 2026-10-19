class_name Sfx
extends Node
## Procedurally synthesised combat sounds (no audio assets needed): swings,
## impacts, dashes, explosions, counters... Generated once, cached, played
## through a small player pool with slight pitch variation. Presentation only.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 24
## Sounds farther than this from the camera focus are faded out.
const HEARING_RANGE: float = 26.0

static var _cache: Dictionary = {}
static var _pool: Array[AudioStreamPlayer] = []
static var _next: int = 0
static var _rng := RandomNumberGenerator.new()
static var volume_db: float = 0.0


const ALL: Array[StringName] = [&"swing", &"swing_heavy", &"hit", &"hit_heavy", &"dash", &"blink", &"throw", &"boom",
	&"fire", &"electric", &"charge", &"counter", &"stun", &"wall_slam", &"heal", &"orb", &"orb_hit", &"ko", &"gong", &"tick"]


## Builds the player pool and synthesises every sound up front (no hitch
## the first time a sound plays).
static func warm_up() -> void:
	if not CombatFx.is_enabled():
		return
	_player()
	for id: StringName in ALL:
		_stream(id)


static func play(id: StringName, at: Vector3 = Vector3.INF, gain_db: float = 0.0, pitch: float = 1.0) -> void:
	if not CombatFx.is_enabled():
		return
	var stream: AudioStreamWAV = _stream(id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _player()
	if player == null:
		return
	var attenuation: float = 0.0
	if at != Vector3.INF:
		var camera := player.get_viewport().get_camera_3d() as ArenaCamera
		if camera != null and camera.target != null:
			var d: float = HitQuery.flat(at - camera.target.global_position).length()
			attenuation = -clampf(d / HEARING_RANGE, 0.0, 1.0) * 14.0
	player.stream = stream
	player.volume_db = volume_db + gain_db + attenuation
	player.pitch_scale = pitch * _rng.randf_range(0.93, 1.07)
	player.play()


static func _player() -> AudioStreamPlayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if not _pool.is_empty() and is_instance_valid(_pool[0]) and not _pool[0].is_inside_tree():
		return null  # still being attached
	if _pool.is_empty() or not is_instance_valid(_pool[0]):
		_pool.clear()
		var holder := Node.new()
		holder.name = "SfxPool"
		tree.root.add_child.call_deferred(holder)
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			p.bus = &"Master"
			holder.add_child(p)
			_pool.append(p)
		return null  # pool is attached next frame
	_next = (_next + 1) % _pool.size()
	return _pool[_next]


static func _stream(id: StringName) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var samples: PackedFloat32Array = _synth(id)
	if samples.is_empty():
		_cache[id] = null
		return null
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	_cache[id] = wav
	return wav


# --- Synthesis ---------------------------------------------------------------

static func _synth(id: StringName) -> PackedFloat32Array:
	_rng.seed = hash(id)
	match id:
		&"swing":
			return _whoosh(0.16, 900.0, 2600.0, 0.55)
		&"swing_heavy":
			return _mix(_whoosh(0.26, 500.0, 1600.0, 0.7), _tone(0.2, 140.0, 70.0, 0.25, 0.0))
		&"hit":
			return _mix(_noise_burst(0.06, 0.7, 3000.0), _tone(0.12, 180.0, 60.0, 0.8, 0.0))
		&"hit_heavy":
			return _drive(_mix(_noise_burst(0.12, 0.9, 1800.0), _tone(0.28, 120.0, 38.0, 1.0, 0.0)), 1.8)
		&"dash":
			return _whoosh(0.24, 1400.0, 500.0, 0.6)
		&"blink":
			return _mix(_tone(0.14, 600.0, 2400.0, 0.35, 0.0), _whoosh(0.12, 3000.0, 1200.0, 0.3))
		&"throw":
			return _whoosh(0.12, 2000.0, 3500.0, 0.45)
		&"boom":
			return _drive(_mix(_noise_burst(0.55, 1.0, 900.0), _tone(0.6, 90.0, 30.0, 1.0, 0.0)), 1.6)
		&"fire":
			return _noise_burst(0.5, 0.6, 1200.0, 0.08)
		&"electric":
			return _crackle(0.45, 0.6)
		&"charge":
			return _tone(0.35, 220.0, 520.0, 0.25, 0.4)
		&"counter":
			return _mix(_bell(0.4, [950.0, 1430.0, 2210.0], 0.55), _noise_burst(0.04, 0.5, 5000.0))
		&"stun":
			return _bell(0.45, [1760.0, 2640.0], 0.35)
		&"wall_slam":
			return _drive(_mix(_noise_burst(0.2, 1.0, 700.0), _tone(0.35, 80.0, 35.0, 1.0, 0.0)), 2.0)
		&"heal":
			return _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.09, 0.3)
		&"orb":
			return _arpeggio([659.0, 880.0, 1175.0, 1568.0], 0.07, 0.35)
		&"orb_hit":
			return _bell(0.2, [1320.0, 1980.0], 0.3)
		&"ko":
			return _mix(_tone(0.7, 300.0, 60.0, 0.6, 0.0), _noise_burst(0.3, 0.4, 600.0))
		&"gong":
			return _bell(1.4, [196.0, 293.0, 415.0, 587.0], 0.6)
		&"tick":
			return _bell(0.12, [1200.0], 0.25)
	return PackedFloat32Array()


static func _len(seconds: float) -> int:
	return int(seconds * MIX_RATE)


## Filtered noise whose brightness sweeps from `f0` to `f1` (Hz).
static func _whoosh(seconds: float, f0: float, f1: float, gain: float) -> PackedFloat32Array:
	var n: int = _len(seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var low: float = 0.0
	var band: float = 0.0
	for i in n:
		var t: float = float(i) / n
		var cutoff: float = lerpf(f0, f1, t)
		var k: float = clampf(TAU * cutoff / MIX_RATE, 0.0, 1.0)
		low += k * (_rng.randf_range(-1.0, 1.0) - low)
		band += k * 0.5 * (low - band)
		var env: float = sin(PI * pow(t, 0.6))
		out[i] = (low - band) * env * gain * 2.2
	return out


## Short noise hit with exponential decay, low-passed at `cutoff`.
static func _noise_burst(seconds: float, gain: float, cutoff: float, attack: float = 0.0) -> PackedFloat32Array:
	var n: int = _len(seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var low: float = 0.0
	var k: float = clampf(TAU * cutoff / MIX_RATE, 0.0, 1.0)
	for i in n:
		var t: float = float(i) / MIX_RATE
		low += k * (_rng.randf_range(-1.0, 1.0) - low)
		var env: float = exp(-t * 6.0 / seconds)
		if attack > 0.0:
			env *= clampf(t / attack, 0.0, 1.0)
		out[i] = low * env * gain * 1.6
	return out


## Sine sweep from f0 to f1 with decay (thumps, zaps). `sustain` 0..1 slows the decay.
static func _tone(seconds: float, f0: float, f1: float, gain: float, sustain: float) -> PackedFloat32Array:
	var n: int = _len(seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / n
		phase += TAU * lerpf(f0, f1, t) / MIX_RATE
		var env: float = lerpf(exp(-t * 5.0), 1.0 - t, sustain) * clampf(t * 60.0, 0.0, 1.0)
		out[i] = sin(phase) * env * gain
	return out


## Inharmonic partials with long decay (metal, chimes, gong).
static func _bell(seconds: float, partials: Array, gain: float) -> PackedFloat32Array:
	var n: int = _len(seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / MIX_RATE
		var v: float = 0.0
		for p in partials.size():
			v += sin(TAU * float(partials[p]) * t) * exp(-t * (3.0 + p * 2.0) / seconds) / (1.0 + p * 0.6)
		out[i] = v * gain * clampf(t * 400.0, 0.0, 1.0)
	return out


## Random gated square crackle (lightning).
static func _crackle(seconds: float, gain: float) -> PackedFloat32Array:
	var n: int = _len(seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var gate: bool = false
	var level: float = 0.0
	for i in n:
		if _rng.randf() < 0.004:
			gate = not gate
			level = _rng.randf_range(0.4, 1.0)
		var t: float = float(i) / n
		var buzz: float = signf(sin(TAU * (90.0 + _rng.randf() * 40.0) * float(i) / MIX_RATE))
		out[i] = (buzz * 0.3 + _rng.randf_range(-1.0, 1.0) * 0.7) * (level if gate else 0.12) * (1.0 - t) * gain
	return out


static func _arpeggio(notes: Array, step: float, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_len(step * notes.size() + 0.25))
	for k in notes.size():
		var start: int = _len(step * k)
		var note: PackedFloat32Array = _bell(0.3, [float(notes[k]), float(notes[k]) * 2.0], gain)
		for i in note.size():
			if start + i < out.size():
				out[start + i] += note[i]
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(a.size(), b.size()))
	for i in out.size():
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out


## Soft clipping for punchier impacts.
static func _drive(a: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	for i in a.size():
		a[i] = tanh(a[i] * amount) * 0.85
	return a
