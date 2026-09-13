class_name HullSpecs
extends RefCounted
## Hull dimensions, kept free of engine singletons so tests can read them.

## Raft hull: width, height (bottom of logs to top of deck), length.
const RAFT_SIZE := Vector3(2.6, 0.5, 3.4)
const RAFT_MASS := 350.0
