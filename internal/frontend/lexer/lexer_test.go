package lexer

import (
	"testing"

	"simplescript/internal/ast"
)

func assertToken(
	t *testing.T,
	tok ast.Token,
	expectedTag ast.TokenType,
	expectedSlice string,
) {
	t.Helper()

	if tok.Tag != expectedTag {
		t.Errorf("Incorrect tag. Expected: %v, Got: %v", expectedTag, tok.Tag)
	}

	if tok.Slice != expectedSlice {
		t.Errorf("Incorrect slice. Expected: '%s', Got: '%s'", expectedSlice, tok.Slice)
	}
}

func TestLexer_SingleCharacterTokens(t *testing.T) {
	input := `= + - * / : { } ( ) , [ ] .`
	l := NewLexer(input)

	assertToken(t, l.Next(), ast.TOKEN_EQUALS, "=")
	assertToken(t, l.Next(), ast.TOKEN_PLUS, "+")
	assertToken(t, l.Next(), ast.TOKEN_MINUS, "-")
	assertToken(t, l.Next(), ast.TOKEN_ASTERISK, "*")
	assertToken(t, l.Next(), ast.TOKEN_SLASH, "/")
	assertToken(t, l.Next(), ast.TOKEN_COLON, ":")
	assertToken(t, l.Next(), ast.TOKEN_LBRACE, "{")
	assertToken(t, l.Next(), ast.TOKEN_RBRACE, "}")
	assertToken(t, l.Next(), ast.TOKEN_LPAREN, "(")
	assertToken(t, l.Next(), ast.TOKEN_RPAREN, ")")
	assertToken(t, l.Next(), ast.TOKEN_COMMA, ",")
	assertToken(t, l.Next(), ast.TOKEN_LBRACKET, "[")
	assertToken(t, l.Next(), ast.TOKEN_RBRACKET, "]")
	assertToken(t, l.Next(), ast.TOKEN_DOT, ".")
}

func TestLexer_TwoCharacterTokens(t *testing.T) {
	input := `== != <= >= ..`
	l := NewLexer(input)

	assertToken(t, l.Next(), ast.TOKEN_EQUAL_EQUAL, "==")
	assertToken(t, l.Next(), ast.TOKEN_BANG_EQUAL, "!=")
	assertToken(t, l.Next(), ast.TOKEN_LESS_EQUAL, "<=")
	assertToken(t, l.Next(), ast.TOKEN_GREATER_EQUAL, ">=")
	assertToken(t, l.Next(), ast.TOKEN_RANGE, "..")
}

func TestLexer_KeywordsAndIdentifiers(t *testing.T) {
	input := `var myVar int const`
	l := NewLexer(input)

	assertToken(t, l.Next(), ast.TOKEN_KW_VAR, "var")
	assertToken(t, l.Next(), ast.TOKEN_IDENTIFIER, "myVar")
	assertToken(t, l.Next(), ast.TOKEN_INT, "int")
	assertToken(t, l.Next(), ast.TOKEN_KW_CONST, "const")
}

func TestLexer_Numbers(t *testing.T) {
	input := `16 3.14`
	l := NewLexer(input)

	assertToken(t, l.Next(), ast.TOKEN_INT, "16")
	assertToken(t, l.Next(), ast.TOKEN_FLOAT, "3.14")
}

func TestLexer_IgnoreComments(t *testing.T) {
	input := `
		// This is a comment
		var x
	`
	l := NewLexer(input)

	assertToken(t, l.Next(), ast.TOKEN_KW_VAR, "var")
	assertToken(t, l.Next(), ast.TOKEN_IDENTIFIER, "x")
}

func TestLexer_Strings(t *testing.T) {
	input := `"hello" 'world' "unterminated`
	l := NewLexer(input)

	assertToken(t, l.Next(), ast.TOKEN_STR, "hello")
	assertToken(t, l.Next(), ast.TOKEN_STR, "world")
	assertToken(t, l.Next(), ast.TOKEN_INVALID, "Unterminated string")
}

func TestLexer_Peek(t *testing.T) {
	input := `var x`
	l := NewLexer(input)

	assertToken(t, l.Peek(), ast.TOKEN_KW_VAR, "var")
	assertToken(t, l.Peek(), ast.TOKEN_KW_VAR, "var")

	assertToken(t, l.Next(), ast.TOKEN_KW_VAR, "var")
	assertToken(t, l.Next(), ast.TOKEN_IDENTIFIER, "x")
}

func TestLexer_EOF(t *testing.T) {
	input := `x`
	l := NewLexer(input)

	assertToken(t, l.Next(), ast.TOKEN_IDENTIFIER, "x")
	assertToken(t, l.Next(), ast.TOKEN_EOF, "")
	assertToken(t, l.Next(), ast.TOKEN_EOF, "")
}
