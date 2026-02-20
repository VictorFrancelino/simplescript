package parser

import (
	"fmt"

	"simplescript/internal/ast"
)

type Parser struct {
	tokens []ast.Token
	pos int
	curToken ast.Token
  peekToken ast.Token
  errors []string
}

func NewParser(tokens []ast.Token) *Parser {
	p := &Parser{
		tokens: tokens,
		pos: 0,
		errors: []string{},
	}

  p.nextToken()
  p.nextToken()

  return p
}

func (p *Parser) Errors() []string {
	return p.errors
}

func (p *Parser) nextToken() {
	p.curToken = p.peekToken

	if p.pos < len(p.tokens) {
		p.peekToken = p.tokens[p.pos]
		p.pos++
	} else {
		p.peekToken = p.tokens[len(p.tokens)-1]
	}
}

func (p *Parser) Parse() (*ast.Program, error) {
	prog := &ast.Program{}

	for !p.curTokenIs(ast.TOKEN_EOF) {
		if stmt := p.parseStatement(); stmt != nil {
			prog.Statements = append(prog.Statements, stmt)
		}

		p.nextToken()
	}

	return prog, nil
}

func (p *Parser) curTokenIs(t ast.TokenType) bool {
	return p.curToken.Tag == t
}

func (p *Parser) peekTokenIs(t ast.TokenType) bool {
	return p.peekToken.Tag == t
}

func (p *Parser) peekError(t ast.TokenType) {
	msg := fmt.Sprintf(
		"expected next token to be %v, got %v instead at line %d, col %d",
		t,
		p.peekToken.Tag,
		p.peekToken.Line,
		p.peekToken.Col,
	)

	p.errors = append(p.errors, msg)
}

func (p *Parser) expectPeek(t ast.TokenType) bool {
  if p.peekTokenIs(t) {
    p.nextToken()
    return true
  }

  p.peekError(t)
  return false
}
