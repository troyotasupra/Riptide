class_name Layers
extends RefCounted
## Physics layer bits, in one place so collision masks stay readable.

const WORLD := 1    ## terrain, deck proxies, static props
const PLAYERS := 2
const BOATS := 4    ## real hulls in the world (never a riding platform — see boat.gd)
const INTERACT := 8 ## things the crosshair can target with E
