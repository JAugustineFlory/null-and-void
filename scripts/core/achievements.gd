class_name Achievements
extends RefCounted
## What a player can earn by name: achievements ("achievement:<id>") and found
## secrets ("secret:<id>"), the same ids that unlock Cosmetics items. Earning one
## shows "Achievement: <name>" (Net.earn), and the co-op lobby lists them.
## Secrets stay off the list until found. How to earn one is the hint of the
## item it unlocks, so the list never says more than the lobby already does.
##
## Names, the notice and the lobby tab: approved by Augustine 2026-10-21 12:25Z
## (plan/approvals/achievements-ui-text.md; "Filed under F" from l3-text.md).

const LIST := [
	{"id": "achievement:book_easy_sql", "name": "Required Reading"},
	{"id": "achievement:easy_sql_half", "name": "Halfway There"},
	{"id": "achievement:easy_sql_done", "name": "Cover to Cover"},
	{"id": "achievement:first_block", "name": "Not Today"},
	{"id": "achievement:floor_g", "name": "Signed In"},
	{"id": "achievement:floor_14", "name": "Back Online"},
	{"id": "achievement:floor_22", "name": "Shift Change"},
	{"id": "achievement:floor_18", "name": "Filed under F"},
	{"id": "secret:mercer_vent_tape", "name": "Mercer's Tape"},
	{"id": "secret:mercer_floppy_1", "name": "Mercer's First Disk"},
	{"id": "secret:roster_thu", "name": "Thursday, Apparently"},
	{"id": "secret:ending_news", "name": "Breaking News"},
]

const NOTICE := "Achievement: %s"


## The display name of `id`, or "" when it isn't a named achievement.
static func name_of(id: String) -> String:
	for a in LIST:
		if a.id == id:
			return a.name
	return ""


static func is_secret(id: String) -> bool:
	return id.begins_with("secret:")


## How to earn `id`: the hint on the first item it unlocks ("" for secrets).
static func hint(id: String) -> String:
	for it in Cosmetics.unlocked_by(id):
		if it.has("hint"):
			return it.hint
	return ""


## The achievements `profile` can see, in LIST order: every achievement, and the
## secrets it has found. Each is {id, name, earned, hint}.
static func shown_to(profile: Profile) -> Array:
	var out := []
	for a in LIST:
		var earned: bool = profile.earned.has(a.id)
		if is_secret(a.id) and not earned:
			continue
		out.append({"id": a.id, "name": a.name, "earned": earned, "hint": hint(a.id)})
	return out
