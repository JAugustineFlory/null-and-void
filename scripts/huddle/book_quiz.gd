class_name BookQuiz
extends RefCounted
## Test yourself: a chapter's quick checks, for one player on their own, from
## the book in their notebook (NotebookPages). Huddles don't ask them any more
## (Augustine, 2026-10-22). Each word's questions come with its page beside them,
## as Books.rounds says; an answer shows its why, and a wrong one asks again.

var chapter: Dictionary
## The questions in the order they're asked: [{q: quiz index, ref: [page index]}].
var steps: Array = []
var at := 0
## After an answer: {choice, right} (choice in the order shown).
var result := {}
var _seed := 0


static func create(id: String, run_seed: int) -> BookQuiz:
	var quiz := BookQuiz.new()
	quiz.chapter = Books.chapter(id)
	quiz._seed = run_seed
	for r in Books.rounds(quiz.chapter):
		for q in r.questions:
			quiz.steps.append({"q": q, "ref": r.ref})
	return quiz


func is_done() -> bool:
	return at >= steps.size()


## The question being asked, with its options in this run's order: {word, q, options, answer, why}.
func question() -> Dictionary:
	if is_done():
		return {}
	var i: int = steps[at].q
	var q: Dictionary = chapter.quiz[i].duplicate()
	q.merge(Books.shuffled(q, _seed, "%s/%d" % [chapter.id, i]), true)
	return q


## The pages on show beside the question (none for a memory question), then
## anything shown for that question alone.
func shown_beside() -> Array:
	if is_done():
		return []
	var q: Dictionary = chapter.quiz[steps[at].q]
	if q.get("closed", false):
		return []
	var out: Array = steps[at].ref.map(func(p): return chapter.pages[p])
	if q.has("also"):
		out.append(q.also)
	return out


## Pick option `choice` (in the order shown). Until it's right, you can pick again.
func answer(choice: int) -> void:
	if is_done() or result.get("right", false):
		return
	result = {"choice": choice, "right": choice == question().answer}


## On to the next question, once this one is answered right.
func next() -> void:
	if result.get("right", false):
		at += 1
		result = {}
