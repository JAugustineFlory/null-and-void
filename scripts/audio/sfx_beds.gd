class_name SfxBeds
extends Node
## The sound of the building itself, under everything else: each floor has its own
## room tone on the Ambience bus, made in code. Offices breathe through their air
## vents; the server floor's fans never stop; the archive is so quiet the pipes
## tick; the power plant's transformers drone; the cold store's compressors hum
## with ice crackling; the machine room rumbles and its pumps thud. Walking onto a
## new floor fades one bed into the next.
##
## It follows the World's current floor, which every machine shares, so the whole
## crew hears the same floor. Only the beds in use are kept in memory.

const RATE := 11025
## Each bed loops this long, in seconds (every tone in one is a whole number of
## cycles in it, so it has no seam).
const LENGTH := 8.0
## Which bed each floor has (World.ROUTE keys). Home base has none: the garage is quiet.
const FLOORS := {
	"level_0": "office_air", "level_1": "server_floor", "level_2": "office_air", "level_3": "archive",
	"level_4": "plant", "level_5": "office_air", "level_6": "cold_store", "level_7": "machine_room",
}
const BEDS := ["office_air", "server_floor", "archive", "plant", "cold_store", "machine_room"]
## How loud each bed sits (dB on the Ambience bus): room tone is felt more than heard.
const DB := {"office_air": -20.0, "server_floor": -14.0, "archive": -24.0, "plant": -13.0, "cold_store": -15.0, "machine_room": -12.0}
## Seconds to fade from one floor's bed into the next.
const FADE := 3.0
const SILENT_DB := -60.0

var world: Node
## The bed playing (or fading in) now, "" for none.
var bed := ""
var _players := {}
var _streams := {}


## Follows `w` (the World) for as long as it exists. One per game.
static func follow(w: Node) -> SfxBeds:
	var music := Music.of(w)
	var b := music.get_node_or_null("Beds") as SfxBeds
	if b == null:
		b = SfxBeds.new()
		b.name = "Beds"
		music.add_child(b)
	b.world = w
	return b


## The bed for the floor the crew is on now.
func pick() -> String:
	if not is_instance_valid(world):
		return ""
	var here = world.get("current")
	if not is_instance_valid(here) or here == world.get("home"):
		return ""
	return FLOORS.get(str(here.get("wing_id")), "")


func _process(delta: float) -> void:
	var want := pick()
	if want != bed:
		bed = want
		if bed != "" and not _players.has(bed):
			var p := AudioStreamPlayer.new()
			p.name = bed
			p.bus = Sfx.AMBIENCE
			p.stream = _stream(bed)
			p.volume_db = SILENT_DB
			add_child(p)
			p.play()
			_players[bed] = p
	for kind in _players.keys():
		var p: AudioStreamPlayer = _players[kind]
		var to: float = DB[kind] if kind == bed else SILENT_DB
		var step: float = (DB[kind] - SILENT_DB) * delta / FADE
		p.volume_db = move_toward(p.volume_db, to, step)
		if kind != bed and p.volume_db <= SILENT_DB:
			p.queue_free()
			_players.erase(kind)
			_streams.erase(kind)  # not kept in memory once it's gone


func _stream(kind: String) -> AudioStream:
	if not _streams.has(kind):
		var recorded: AudioStream = Sfx._recorded("bed_" + kind, Sfx.DIR)
		_streams[kind] = recorded if recorded else make(kind)
	return _streams[kind]


## The bed called `kind`, ready to loop, or null.
static func make(kind: String) -> AudioStreamWAV:
	if kind not in BEDS:
		return null
	var n := int(LENGTH * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	match kind:
		"office_air": _office_air(out)
		"server_floor": _server_floor(out)
		"archive": _archive(out)
		"plant": _plant(out)
		"cold_store": _cold_store(out)
		"machine_room": _machine_room(out)
	_level(out, 0.6)
	return SfxSynth._loop(SfxSynth._wav(out, RATE))


## Scales `out` so its loudest point is `peak`.
static func _level(out: PackedFloat32Array, peak: float) -> void:
	var top := 0.0
	for v in out:
		top = maxf(top, absf(v))
	if top > 0.0:
		for i in out.size():
			out[i] *= peak / top


## Air moving through ceiling vents, and the faint buzz of the tubes overhead.
static func _office_air(out: PackedFloat32Array) -> void:
	var air := SfxSynth._noise("bed_office_air", out.size(), 0.05)
	var hiss := SfxSynth._noise("bed_office_hiss", out.size(), 0.5)
	for i in out.size():
		var t := float(i) / RATE
		var breathe := 0.85 + 0.15 * sin(TAU * t / LENGTH)
		out[i] = air[i] * 6.0 * breathe + hiss[i] * 0.05 + sin(TAU * 120.0 * t) * 0.02


## Rows of racks: fan rush, the whine of a hundred small fans, two of them beating.
static func _server_floor(out: PackedFloat32Array) -> void:
	var rush := SfxSynth._noise("bed_server_rush", out.size(), 0.35)
	var deep := SfxSynth._noise("bed_server_deep", out.size(), 0.03)
	for i in out.size():
		var t := float(i) / RATE
		var beat := 0.7 + 0.3 * sin(TAU * 0.75 * t)
		out[i] = rush[i] * 0.5 + deep[i] * 4.0 + (sin(TAU * 440.0 * t) + sin(TAU * 441.5 * t)) * 0.03 * beat + sin(TAU * 60.0 * t) * 0.12


## Rows of shelves and still air. Almost nothing; a pipe ticks somewhere, twice.
static func _archive(out: PackedFloat32Array) -> void:
	var still := SfxSynth._noise("bed_archive", out.size(), 0.02)
	for i in out.size():
		out[i] = still[i] * 5.0
	for at in [1.9, 6.3]:
		_tick(out, at, 0.45, 2600.0)


## Transformers: a hard 60 Hz drone and its harmonics, and machinery grinding under it.
static func _plant(out: PackedFloat32Array) -> void:
	var grind := SfxSynth._noise("bed_plant", out.size(), 0.08)
	for i in out.size():
		var t := float(i) / RATE
		var drone := sin(TAU * 60.0 * t) + sin(TAU * 120.0 * t) * 0.6 + sin(TAU * 180.0 * t) * 0.35 + sin(TAU * 300.0 * t) * 0.12
		out[i] = clampf(drone * 0.5, -0.4, 0.4) + grind[i] * 2.5 * (0.8 + 0.2 * sin(TAU * 0.25 * t))


## Compressors humming on two notes that won't agree, the hiss of cold air, and ice
## settling now and then.
static func _cold_store(out: PackedFloat32Array) -> void:
	var cold := SfxSynth._noise("bed_cold_hiss", out.size(), 0.7)
	var low := SfxSynth._noise("bed_cold_low", out.size(), 0.02)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (sin(TAU * 49.0 * t) + sin(TAU * 49.5 * t)) * 0.18 + sin(TAU * 98.0 * t) * 0.06 + cold[i] * 0.06 + low[i] * 3.0
	for at in [0.7, 3.1, 3.25, 5.8]:
		_tick(out, at, 0.25, 4200.0)


## The machine room: a big low rumble, and a pump that thuds every two seconds.
static func _machine_room(out: PackedFloat32Array) -> void:
	var rumble := SfxSynth._noise("bed_machine", out.size(), 0.015)
	var clank := SfxSynth._noise("bed_machine_clank", out.size(), 0.6)
	for i in out.size():
		var t := float(i) / RATE
		var into := fmod(t, 2.0)
		var thud := sin(TAU * (45.0 - 15.0 * into) * into) * exp(-into * 9.0)
		out[i] = rumble[i] * 8.0 + sin(TAU * 30.0 * t) * 0.15 + thud * 0.5 + clank[i] * 0.08 * exp(-into * 20.0)


## A small sharp tick at `at` seconds: a pipe, or ice. Rings at `ring` Hz.
static func _tick(out: PackedFloat32Array, at: float, amp: float, ring: float) -> void:
	var start := int(at * RATE)
	for k in int(0.05 * RATE):
		var s := float(k) / RATE
		out[(start + k) % out.size()] += sin(TAU * ring * s) * exp(-s * 140.0) * amp
