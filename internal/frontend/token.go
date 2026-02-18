package frontend

import "simplescript/internal/ast"

var keywords = map[string]ast.TokenType{
	"var": ast.TOKEN_KW_VAR,
	"const": ast.TOKEN_KW_CONST,
	"for": ast.TOKEN_KW_FOR,
	"in": ast.TOKEN_KW_IN,
	"if": ast.TOKEN_KW_IF,
	"else": ast.TOKEN_KW_ELSE,
	"true": ast.TOKEN_KW_TRUE,
	"false": ast.TOKEN_KW_FALSE,
}

func getKeyword(text string) ast.TokenType {
	if tag, ok := keywords[text]; ok {
		return tag
	}

	return ast.TOKEN_IDENTIFIER
}
