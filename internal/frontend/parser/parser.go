package parser

import (
	"fmt"

	"simplescript/internal/ast"
)

type Parser struct {
	tokens []ast.Token
	pos int
  errors []string
}

func NewParser(tokens []ast.Token) *Parser {
	return &Parser{
		tokens: tokens,
		pos: 0,
		errors: []string{},
	}
}

func (p *Parser) Parse() *ast.Program {
	prog := &ast.Program{}

	for !p.isAtEnd() {
		stmt := p.parseStatement()

		if stmt != nil {
			prog.Statements = append(prog.Statements, stmt)
		} else {
			p.advance()
		}
	}

	return prog
}

func (p *Parser) Errors() []string {
	return p.errors
}

func (p *Parser) current() ast.Token {
	if p.pos >= len(p.tokens) {
		return p.tokens[len(p.tokens)-1]
	}

	return p.tokens[p.pos]
}

func (p *Parser) previous() ast.Token {
	return p.tokens[p.pos-1]
}

func (p *Parser) isAtEnd() bool {
	return p.current().Tag == ast.TOKEN_EOF
}

func (p *Parser) check(t ast.TokenType) bool {
	if p.isAtEnd() { return false }
	return p.current().Tag == t
}

func (p *Parser) advance() ast.Token {
	if p.current().Tag != ast.TOKEN_EOF {
		p.pos++
	}

	return p.previous()
}

func (p *Parser) match(types ...ast.TokenType) bool {
	for _, t := range types {
		if p.check(t) {
			p.advance()
			return true
		}
	}

	return false
}

func (p *Parser) consume(t ast.TokenType, errMsg string) ast.Token {
	if p.check(t) {
		return p.advance()
	}

	msg := fmt.Sprintf(
		"Syntax Error at line %d, col %d: %s. Got '%s' instead.",
		p.current().Line,
		p.current().Col,
		errMsg,
		p.current().Slice,
	)
	p.errors = append(p.errors, msg)

	return ast.Token{Tag: ast.TOKEN_INVALID}
}
