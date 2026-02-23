package parser

import (
	"fmt"
	"os"

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

func MustParse(tokens []ast.Token) *ast.Program {
	p := NewParser(tokens)
	program := p.parse()

	if len(p.errors) > 0 {
		fmt.Println("Syntax Errors found:")
		for _, msg := range p.errors {
			fmt.Printf(" - %s\n", msg)
		}
		os.Exit(1)
	}

	return program
}

func (p *Parser) parse() *ast.Program {
	prog := &ast.Program{}

	for !p.isAtEnd() {
		if stmt := p.parseStatement(); stmt != nil {
			prog.Statements = append(prog.Statements, stmt)
		} else {
			p.advance()
		}
	}

	return prog
}

func (p *Parser) addError(msg string) {
	cur := p.current()
	err := fmt.Sprintf(
		"Syntax Error at line %d, col %d: %s. Got '%s' instead.",
		cur.Line,
		cur.Col,
		msg,
		cur.Slice,
	)
	p.errors = append(p.errors, err)
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
	if !p.isAtEnd() {
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

	p.addError(errMsg)

	return ast.Token{Tag: ast.TOKEN_INVALID}
}
