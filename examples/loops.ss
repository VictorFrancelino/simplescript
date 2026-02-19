// Loops with Static and Dynamic Ranges

say('Counting 0 to 4:')
for i in 0..5 {
  say('Number:', i)
}

say('Using variables for range (5 to 9):')
var start: int = 5
var end: int = 10
for i in start..end {
  say('Dynamic index:', i)
}

say('Calculating sum of 0 to 9:')
var sum: int = 0
for i in 0..10 {
  // Variables can be updated using their current value
  sum = sum + i
}

say('Total sum of 0..9 is:', sum)
