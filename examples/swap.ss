// The magic of Multiple Assignment (Swap)
// No temporary variables needed!

var player_1: int = 500
var player_2: int = 1000

say('Initial Scores:', player_1, player_2)

say('Swapping scores...')
player_1, player_2 = player_2, player_1

say('New Scores:', player_1, player_2)

// Triple swap showcase
var r: int = 255
var g: int = 128
var b: int = 0

say('RGB values:', r, g, b)

say('Rotating RGB values...')

r, g, b = g, b, r
say('RGB values:', r, g, b)
