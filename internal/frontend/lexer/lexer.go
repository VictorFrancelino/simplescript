package lexer

import (
	"fmt"
	"os"

	"simplescript/internal/ast"
)

// it transforms the source code into a sequence of logical units (Tokens)
type Lexer struct {
	buffer string
	pos int
	line int
	col int
}

// initializes Lexer with the source code.
func NewLexer(buffer string) *Lexer {
	return &Lexer{ buffer: buffer, line: 1, col: 1, }
}

func MustTokenize(source string) []ast.Token {
	l := NewLexer(source)
	tokens := l.tokenize()

	for _, token := range tokens {
		if token.Tag == ast.TOKEN_INVALID {
			fmt.Printf(
				"Lexical Error [%d:%d]: invalid token '%s'\n",
				token.Line,
				token.Col,
				token.Slice,
			)
			os.Exit(1)
		}
	}

	return tokens
}

// reads the entire buffer and returns all tokens at once
func (l *Lexer) tokenize() []ast.Token {
	var tokens []ast.Token

	for {
		tok := l.scanToken()
		tokens = append(tokens, tok)

		if tok.Tag == ast.TOKEN_EOF {
			break
		}
	}

	return tokens
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
