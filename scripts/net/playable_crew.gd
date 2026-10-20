class_name PlayableCrew
extends RefCounted
## The twelve crew members players choose between in the lobby, six on each body
## type. Approved by Augustine 2026-10-20 (script/drafts/playable-crew.md).
## Each one's barks and effort sounds are recorded under
## audio/voice/crew_<slug>/; Graphics builds their looks.

const CAST := [
	{"slug": "dana", "name": "Dana Okafor", "age": "30s", "body": 2, "about": "Ex-cable installer"},
	{"slug": "priya", "name": "Priya Raman", "age": "20s", "body": 2, "about": "Ran a phone-repair kiosk at the mall"},
	{"slug": "rosa", "name": "Rosa Delgado", "age": "50s", "body": 2, "about": "A retired school secretary"},
	{"slug": "kit", "name": "Kit Larsen", "age": "20s", "body": 2, "about": "Bike courier and rooftop free-runner"},
	{"slug": "june", "name": "June Whitaker", "age": "60s", "body": 2, "about": "Ham-radio operator for forty years"},
	{"slug": "mei", "name": "Mei Tanaka", "age": "30s", "body": 2, "about": "Ex-barista with a nervous laugh"},
	{"slug": "marcus", "name": "Marcus Bell", "age": "40s", "body": 1, "about": "Former mall security guard"},
	{"slug": "theo", "name": "Theo Brandt", "age": "20s", "body": 1, "about": "A gamer with a sarcastic streak"},
	{"slug": "sam", "name": "Sam Abara", "age": "30s", "body": 1, "about": "Professional mover"},
	{"slug": "luis", "name": "Luis Ortega", "age": "50s", "body": 1, "about": "Handyman"},
	{"slug": "ike", "name": "Ike Novak", "age": "20s", "body": 1, "about": "A startup dropout who talks in buzzwords"},
	{"slug": "walt", "name": "Walt Henley", "age": "60s", "body": 1, "about": "Retired lineman"},
]


static func slugs() -> Array:
	return CAST.map(func(c): return c.slug)


## One crew member's entry, or {} if there's no such slug.
static func info(slug: String) -> Dictionary:
	for c in CAST:
		if c.slug == slug:
			return c
	return {}


## The slugs on body type `body` (1 or 2), in CAST order.
static func on_body(body: int) -> Array:
	return CAST.filter(func(c): return c.body == body).map(func(c): return c.slug)
