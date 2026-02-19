package lexer

import "simplescript/internal/ast"

// creates a populated ast.Token structure
func (l *Lexer) newToken(
	tag ast.TokenType,
	slice string,
	line,
	col int,
) ast.Token {
	return ast.Token{ Tag: tag, Slice: slice, Line: line, Col: col, }
}

// it consumes the current character and updates the row and column coordinates
func (l *Lexer) advance() byte {
	if l.pos >= len(l.buffer) {
		return 0
	}

	char := l.buffer[l.pos]

	l.pos++

	if char == '\n' {
		l.line++
		l.col = 1
	} else {
		l.col++
	}

	return char
}

// the cursor advances only if the next character is the expected one
func (l *Lexer) match(expected byte) bool {
	if l.pos >= len(l.buffer) || l.buffer[l.pos] != expected {
		return false
	}

	l.advance()

	return true
}

// view characters ahead without moving the cursor
func (l *Lexer) peekChar(offset int) byte {
	target := l.pos + offset
	if target < len(l.buffer) {
		return l.buffer[target]
	}

	return 0
}

// skips spaces, tabs, and line breaks
func (l *Lexer) skipWhitespace() {
	for l.pos < len(l.buffer) {
		char := l.peekChar(0)

		if char == ' ' || char == '\t' || char == '\r' || char == '\n' {
			l.advance()
		} else {
			break
		}
	}
}
