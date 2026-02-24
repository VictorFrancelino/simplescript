package ast

type TokenType int

type Token struct {
  Tag TokenType
  Slice string
  Line int
  Col int
}

const (
	// Operators
	TOKEN_PLUS TokenType = iota
	TOKEN_MINUS
	TOKEN_ASTERISK
	TOKEN_SLASH
	TOKEN_EQUALS
	TOKEN_COMMA
	TOKEN_DOT

	// Delimiters
	TOKEN_LPAREN
	TOKEN_RPAREN
	TOKEN_LBRACE
	TOKEN_RBRACE
	TOKEN_LBRACKET
	TOKEN_RBRACKET
	TOKEN_RANGE

	// Keywords
	TOKEN_KW_VAR
	TOKEN_KW_CONST
	TOKEN_KW_FOR
	TOKEN_KW_IN
	TOKEN_KW_IF
	TOKEN_KW_ELSE
	TOKEN_KW_TRUE
	TOKEN_KW_FALSE
	TOKEN_KW_CONTINUE
	TOKEN_KW_FUNC
	TOKEN_KW_RETURN
	TOKEN_KW_BREAK

	// Literals
	TOKEN_JSON
	TOKEN_STR
	TOKEN_INT
	TOKEN_FLOAT
	TOKEN_BOOL
	TOKEN_LIST
	TOKEN_MAP
	TOKEN_IDENTIFIER

	// Special
	TOKEN_PLUS_EQUAL
	TOKEN_MINUS_EQUAL
	TOKEN_SLASH_EQUAL
	TOKEN_ASTERISK_EQUAL
	TOKEN_EQUAL_EQUAL
	TOKEN_BANG_EQUAL
	TOKEN_GREATER_EQUAL
	TOKEN_GREATER
	TOKEN_LESS_EQUAL
	TOKEN_LESS
	TOKEN_COLON
	TOKEN_EOF
	TOKEN_INVALID
)

// Keywords mapping for the Lexer
var keywords = map[string]TokenType{
	// Basic Types
	"json": TOKEN_JSON,
	"str": TOKEN_STR,
	"int": TOKEN_INT,
	"float": TOKEN_FLOAT,
	"bool": TOKEN_BOOL,
	"list": TOKEN_LIST,
	"map": TOKEN_MAP,

	// Declarations
	"var": TOKEN_KW_VAR,
	"const": TOKEN_KW_CONST,

	// Control Flow
	"for": TOKEN_KW_FOR,
	"in": TOKEN_KW_IN,
	"break": TOKEN_KW_BREAK,
	"continue": TOKEN_KW_CONTINUE,
	"if": TOKEN_KW_IF,
	"else": TOKEN_KW_ELSE,

	// Booleans
	"true": TOKEN_KW_TRUE,
	"false": TOKEN_KW_FALSE,

	// functions
	"func": TOKEN_KW_FUNC,
	"return": TOKEN_KW_RETURN,
}

// Checks if an identifier is a reserved keyword
func GetKeyword(text string) TokenType {
	if tag, ok := keywords[text]; ok {
		return tag
	}

	return TOKEN_IDENTIFIER
}
