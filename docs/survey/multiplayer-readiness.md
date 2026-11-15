# Survey: multiplayer-readiness

## High-level multiplayer — https://raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/networking/high_level_multiplayer.rst

> In general, TCP can be thought of as reliable, ordered, and slow; UDP as unreliable, unordered and fast.

> In summary, you can use the low-level networking API for maximum control and implement everything on top of bare network protocols or use the high-level API based on :ref:`SceneTree <class_SceneTree>` that does most of the heavy lifting behind the scenes in a generally optimized way.

> provides an implementation based on ENet (:ref:`ENetMultiplayerPeer <class_ENetMultiplayerPeer>`),

> high-level multiplayer API only uses UDP, so you must forward the port in UDP,

> Godot's high-level multiplayer API uses a modified version of ENet which allows
> for full IPv6 support.

## MultiplayerSynchronizer (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/multiplayer/doc_classes/MultiplayerSynchronizer.xml

> Synchronizes properties from the multiplayer authority to the remote peers.

## MultiplayerSpawner (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/modules/multiplayer/doc_classes/MultiplayerSpawner.xml

> Automatically replicates spawnable nodes from the authority to other multiplayer peers.

## Engine class reference (4.7.2) — https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/Engine.xml

> [b]Note:[/b] When using a custom physics interpolation solution, or within a network game, it's recommended to disable the physics jitter fix by setting this property to [code]0[/code].

## Build brief, Rules

> So no code assumes there is exactly one player, and what belongs to a player (body, input, camera, timer, checkpoint, collectibles) is kept apart from what belongs to the world. A ghost is already a second body in the world: build ghosts so that a live player on another machine could later take a ghost's place.
