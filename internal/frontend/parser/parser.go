package parser

import (
	"fmt"

	"simplescript/internal/ast"
	"simplescript/internal/frontend/lexer"
)

type Parser struct {
	lexer *lexer.Lexer
	curToken ast.Token
  peekToken ast.Token
  errors []string
}

func NewParser(l *lexer.Lexer) *Parser {
	p := &Parser{
		lexer: l,
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
	p.peekToken = p.lexer.Next()
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
