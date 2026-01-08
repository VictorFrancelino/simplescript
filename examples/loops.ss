// Demonstrates loops with static and dynamic ranges

say('Counting 0 to 4:')
for i in 0..5 {
  say(i)
}

say('Using variables for range (5 to 9):')
var start: int = 0
var end: int = 5
for i in start..end {
  say(i)
}

say('Calculating sum of 0 to 9:')
var sum: int = 0
for i in 0..10 {
  sum = sum + i
}

say('Total sum:', sum)
