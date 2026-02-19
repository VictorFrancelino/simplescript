package ast

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
