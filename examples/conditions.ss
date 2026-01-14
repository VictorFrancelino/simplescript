// Conditional Logic and Comparisons
// Supports if, else if, and else blocks with boolean expressions

var age: int = 18

say('Checking age status...')
if age >= 18 {
  say('Status: You are an adult')
} else if age >= 0 {
  say('Status: You are a minor')
} else {
  say('ERROR: Invalid age value')
}

// Boolean literals usage
say('Boolean testing:')
if true {
  say('True branch works')
} else {
  say('This should not print')
}

// String comparisons
var name: str = "Victor Francelino"
say('Checking identity for:', name)

if name != "SimpleScript" {
  say('The strings are different')
} else {
  say('The strings are equal')
}

// Integer equality check
var target: int = 16

if target == 16 {
  say('Target confirmed: 16')
} else {
  say('Target mismatch')
}
