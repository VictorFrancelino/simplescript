package frontend

import "simplescript/internal/ast"

type Lexer struct {
	buffer string
	pos int
	line int
	col int
	peekedToken *ast.Token
}

func NewLexer(buffer string) *Lexer {
	return &Lexer{ buffer: buffer, line: 1, col: 1, }
}

func (l *Lexer) newToken(
	tag ast.TokenType,
	slice string,
	line,
	col int,
) ast.Token {
	return ast.Token{
		Tag: tag,
		Slice: slice,
		Line: line,
		Col: col,
	}
}

func (l *Lexer) match(expected byte) bool {
	if l.pos >= len(l.buffer) || l.buffer[l.pos] != expected {
		return false
	}

	l.advance()

	return true
}

func (l *Lexer) Next() ast.Token {
	if l.peekedToken != nil {
		tok := *l.peekedToken
		l.peekedToken = nil

		return tok
	}

	return l.scanToken()
}

func (l *Lexer) Peek() ast.Token {
	if l.peekedToken != nil {
		return *l.peekedToken
	}

	tok := l.scanToken()
	l.peekedToken = &tok

	return tok
}

func (l *Lexer) scanToken() ast.Token {
	l.skipWhitespace()

	startLine := l.line
	startCol := l.col
	startPos := l.pos

	if l.pos >= len(l.buffer) {
		return l.newToken(ast.TOKEN_EOF, "", startLine, startCol)
	}

	char := l.advance()

	switch char {
	case '(': return l.newToken(ast.TOKEN_LPAREN, "(", startLine, startCol)
	case ')': return l.newToken(ast.TOKEN_RPAREN, ")", startLine, startCol)
	case '{': return l.newToken(ast.TOKEN_LBRACE, "{", startLine, startCol)
	case '}': return l.newToken(ast.TOKEN_RBRACE, "}", startLine, startCol)
	case '+': return l.newToken(ast.TOKEN_PLUS, "+", startLine, startCol)
	case '-': return l.newToken(ast.TOKEN_MINUS, "-", startLine, startCol)
	case '*': return l.newToken(ast.TOKEN_ASTERISK, "*", startLine, startCol)
	case ':': return l.newToken(ast.TOKEN_COLON, ":", startLine, startCol)
	case ',': return l.newToken(ast.TOKEN_COMMA, ",", startLine, startCol)
	case '/':
		if l.match('/') {
			for l.pos < len(l.buffer) && l.peekChar(0) != '\n' {
				l.advance()
			}

			return l.scanToken()
		}

		return l.newToken(ast.TOKEN_SLASH, "/", startLine, startCol)
	case '=':
		if l.match('=') {
			return l.newToken(ast.TOKEN_EQUAL_EQUAL, "==", startLine, startCol)
		}

		return l.newToken(ast.TOKEN_EQUALS, "=", startLine, startCol)
	case '!':
		if l.match('=') {
			return l.newToken(ast.TOKEN_BANG_EQUAL, "!=", startLine, startCol)
		}

		return l.newToken(ast.TOKEN_INVALID, "!", startLine, startCol)
	case '<':
		if l.match('=') {
			return l.newToken(ast.TOKEN_LESS_EQUAL, "<=", startLine, startCol)
		}

		return l.newToken(ast.TOKEN_LESS, "<", startLine, startCol)
	case '>':
		if l.match('=') {
			return l.newToken(ast.TOKEN_GREATER_EQUAL, ">=", startLine, startCol)
		}

		return l.newToken(ast.TOKEN_GREATER, ">", startLine, startCol)
	case '.':
		if l.match('.') {
			return l.newToken(ast.TOKEN_RANGE, "..", startLine, startCol)
		}

		return l.newToken(ast.TOKEN_INVALID, ".", startLine, startCol)
	case '"', '\'':
		return l.scanString(char, startLine, startCol)
	}

	if isDigit(char) { return l.scanNumber(startPos, startLine, startCol) }

	if isAlpha(char) { return l.scanIdentifier(startPos, startLine, startCol) }

	return l.newToken(ast.TOKEN_INVALID, string(char), startLine, startCol)
}

func (l *Lexer) scanString(delimiter byte, line, col int) ast.Token {
	start := l.pos

	for l.pos < len(l.buffer) && l.buffer[l.pos] != delimiter {
		l.advance()
	}

	content := l.buffer[start:l.pos]

	if l.pos < len(l.buffer) { l.advance() }

	return l.newToken(ast.TOKEN_STRING, content, line, col)
}

func (l *Lexer) scanNumber(startPos, line, col int) ast.Token {
	isFloat := false

	for l.pos < len(l.buffer) {
		c := l.peekChar(0)

		if c == '.' && isDigit(l.peekChar(1)) {
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

	return l.newToken(getKeyword(slice), slice, line, col)
}

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

func (l *Lexer) peekChar(offset int) byte {
	target := l.pos + offset
	if target < len(l.buffer) {
		return l.buffer[target]
	}

	return 0
}

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
