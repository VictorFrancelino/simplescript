// Multiple Assignment and Value Swapping
// In SimpleScript, you don't need temporary variables to swap values!

var player_1: int = 500
var player_2: int = 1000

say('Initial Scores -> P1:', player_1, '| P2:', player_2)

say('Swapping scores...')

// Multiple values are evaluated and assigned simultaneously
player_1, player_2 = player_2, player_1

say('New Scores -> P1:', player_1, '| P2:', player_2)

// It also works for rotating multiple values
var r: int = 255
var g: int = 128
var b: int = 0

say('RGB values:', r, g, b)
say('Rotating RGB values...')

r, g, b = g, b, r
say('RGB values:', r, g, b)
