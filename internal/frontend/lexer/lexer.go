package lexer

import "simplescript/internal/ast"

// it transforms the source code into a sequence of logical units (Tokens)
type Lexer struct {
	buffer string
	pos int
	line int
	col int
	peekedToken *ast.Token
}

// initializes Lexer with the source code.
func NewLexer(buffer string) *Lexer {
	return &Lexer{ buffer: buffer, line: 1, col: 1, }
}

// returns the next token and advances the cursor
func (l *Lexer) Next() ast.Token {
	if l.peekedToken != nil {
		tok := *l.peekedToken
		l.peekedToken = nil

		return tok
	}

	return l.scanToken()
}

// allows you to view the next token without consuming it
func (l *Lexer) Peek() ast.Token {
	if l.peekedToken != nil {
		return *l.peekedToken
	}

	tok := l.scanToken()
	l.peekedToken = &tok

	return tok
}

// master function that identifies which token is next in the buffer
func (l *Lexer) scanToken() ast.Token {
	l.skipWhitespace()

	startLine := l.line
	startCol := l.col
	startPos := l.pos

	if l.pos >= len(l.buffer) {
		return l.newToken(ast.TOKEN_EOF, "", startLine, startCol)
	}

	char := l.advance()

	if isAlpha(char) {
		return l.scanIdentifier(startPos, startLine, startCol)
	}

	if isDigit(char) {
		return l.scanNumber(startPos, startLine, startCol)
	}

	switch char {
	case '(': return l.newToken(ast.TOKEN_LPAREN, "(", startLine, startCol)
	case ')': return l.newToken(ast.TOKEN_RPAREN, ")", startLine, startCol)
	case '{': return l.newToken(ast.TOKEN_LBRACE, "{", startLine, startCol)
	case '}': return l.newToken(ast.TOKEN_RBRACE, "}", startLine, startCol)
	case '[': return l.newToken(ast.TOKEN_LBRACKET, "[", startLine, startCol)
	case ']': return l.newToken(ast.TOKEN_RBRACKET, "]", startLine, startCol)
	case '+': return l.newToken(ast.TOKEN_PLUS, "+", startLine, startCol)
	case '-': return l.newToken(ast.TOKEN_MINUS, "-", startLine, startCol)
	case '*': return l.newToken(ast.TOKEN_ASTERISK, "*", startLine, startCol)
	case ':': return l.newToken(ast.TOKEN_COLON, ":", startLine, startCol)
	case ',': return l.newToken(ast.TOKEN_COMMA, ",", startLine, startCol)
	case '/': return l.newToken(ast.TOKEN_SLASH, "/", startLine, startCol)
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

		return l.newToken(ast.TOKEN_DOT, ".", startLine, startCol)
	case '"', '\'':
		return l.scanString(char, startLine, startCol)
	}

	return l.newToken(ast.TOKEN_INVALID, string(char), startLine, startCol)
}
