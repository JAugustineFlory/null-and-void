extends StaticBody3D
## The garage's punch bag: it hangs from its hook (this node) and swings about it.
## A strike on it is the cue for its swing back (HomeBase._on_bag_struck).

## Host: someone struck the bag.
signal struck(by: Node)


## Called by the player's strike. In co-op a client's strike goes to the host.
func take_hit(by: Node) -> void:
	var sync := LevelSync.of(self)
	if sync and sync.forward(self, "take_hit"):
		return
	struck.emit(by)
