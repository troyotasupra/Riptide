class_name MovementTuning
extends RefCounted
## Movement feel numbers, kept free of engine singletons so tests can read them.

## Game gravity, not real-world 9.8 — real gravity makes jumps feel like the moon.
const GRAVITY := 24.0
## Extra gravity while falling so jumps land snappily.
const FALL_MULTIPLIER := 1.35
const JUMP_VELOCITY := 7.0
## Strong enough to climb out of the water onto a raft deck.
const SWIM_JUMP_VELOCITY := 9.0
## How deep your feet hang while treading water.
const SWIM_FLOAT_DEPTH := 1.2
