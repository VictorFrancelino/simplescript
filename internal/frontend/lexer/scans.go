package lexer

import "simplescript/internal/ast"

// it consumes characters until it finds the closing delimiter
func (l *Lexer) scanString(delimiter byte, line, col int) ast.Token {
	start := l.pos

	for l.pos < len(l.buffer) {
		char := l.buffer[l.pos]

		if char == '\\' {
			l.advance()
			l.advance()
			continue
		}

		if char == delimiter {
			break
		}

		l.advance()
	}

	content := l.buffer[start:l.pos]

	if l.pos < len(l.buffer) {
		l.advance()
	}

	return l.newToken(ast.TOKEN_STR, content, line, col)
}

// processes numeric literals and decides whether they are integers or floats
func (l *Lexer) scanNumber(startPos, line, col int) ast.Token {
	isFloat := false

	for l.pos < len(l.buffer) {
		c := l.peekChar(0)

		if c == '.' && isDigit(l.peekChar(1)) {
			if isFloat { break }

			isFloat = true
			l.advance()
		} else if isDigit(c) {
			l.advance()
		} else {
			break
		}
	}

	tag := ast.TOKEN_INT
	if isFloat { tag = ast.TOKEN_FLOAT }

	return l.newToken(tag, l.buffer[startPos:l.pos], line, col)
}

// it groups letters and numbers and checks if the word is a reserved keyword
func (l *Lexer) scanIdentifier(startPos, line, col int) ast.Token {
	for l.pos < len(l.buffer) {
		c := l.peekChar(0)

		if isAlphaNumeric(c) {
			l.advance()
		} else {
			break
		}
	}

	slice := l.buffer[startPos:l.pos]

	return l.newToken(ast.GetKeyword(slice), slice, line, col)
}
