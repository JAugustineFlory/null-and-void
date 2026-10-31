class_name CrewBody
extends RefCounted
## How big a crew member is, from the character they play (CharacterLooks
## "height" and body type): how tall they stand, crouch, crawl and sit, how wide
## they are and where their eyes sit. Size 1.0 is the standard body the Player
## constants describe (1.8 m standing); every measurement scales with it, so a
## short crew member is smaller to bump into and sees the world from lower down.
## How far you can reach and jump stays the same for everyone.
##
## Every route in the building has to fit the largest crew body and work for the
## smallest (tests/body_tests.gd sweeps each floor). Per-character attributes
## (run speed, stamina, jump) belong here too when they come.

## How tall each body type's model is at height 1.0 (CharacterLooks.CREW_BODIES).
const BODY_TALL := {1: 1.81, 2: 1.77}

## Scale on the standard body: 1.0 is 1.8 m tall standing.
var size := 1.0

## Standing, crouching, crawling and sitting heights, and the body's radius.
var stand: float:
	get:
		return Player.STAND_HEIGHT * size
var crouch: float:
	get:
		return Player.CROUCH_HEIGHT * size
var crawl: float:
	get:
		return Player.CRAWL_HEIGHT * size
var sit: float:
	get:
		return Player.SIT_HEIGHT * size
var radius: float:
	get:
		return Player.RADIUS * size


func _init(body_size: float = 1.0) -> void:
	size = body_size


## The body for a CharacterLooks look (NetPlayers.look_for).
static func from_look(look: Dictionary) -> CrewBody:
	var tall: float = BODY_TALL.get(int(look.get("body", 1)), BODY_TALL[1])
	return CrewBody.new(float(look.get("height", 1.0)) * tall / Player.STAND_HEIGHT)


## A playable crew member's body (PlayableCrew slug).
static func of_crew(slug: String) -> CrewBody:
	return from_look(CharacterLooks.outfit({"crew": slug, "body": PlayableCrew.info(slug).get("body", 1)}))


## The biggest and smallest bodies in the crew: what every route must fit, and
## what every jump and reach must still work for.
static func largest() -> CrewBody:
	var out := CrewBody.new(0.0)
	for slug in PlayableCrew.slugs():
		var b := of_crew(slug)
		if b.size > out.size:
			out = b
	return out


static func smallest() -> CrewBody:
	var out := CrewBody.new(INF)
	for slug in PlayableCrew.slugs():
		var b := of_crew(slug)
		if b.size < out.size:
			out = b
	return out


## Eye height for a body `height` tall right now (standing, crouching, sitting...).
func eyes(height: float) -> float:
	return height - 0.12 * size


## Below this height you're on hands and knees rather than crouching.
func crawling_below() -> float:
	return 1.0 * size
