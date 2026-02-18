package frontend

import (
	"strconv"
	"simplescript/internal/ast"
)

const (
	PREC_NONE int = iota
	PREC_ASSIGNMENT
	PREC_LOGICAL
	PREC_COMPARISON
	PREC_TERM
	PREC_FACTOR
	PREC_UNARY
	PREC_CALL
	PREC_PRIMARY
)

var precedences = map[ast.TokenType]int{
	ast.TOKEN_EQUAL_EQUAL: PREC_COMPARISON,
	ast.TOKEN_BANG_EQUAL: PREC_COMPARISON,
	ast.TOKEN_LESS: PREC_COMPARISON,
	ast.TOKEN_LESS_EQUAL: PREC_COMPARISON,
	ast.TOKEN_GREATER: PREC_COMPARISON,
	ast.TOKEN_GREATER_EQUAL: PREC_COMPARISON,
	ast.TOKEN_PLUS: PREC_TERM,
	ast.TOKEN_MINUS: PREC_TERM,
	ast.TOKEN_ASTERISK: PREC_FACTOR,
	ast.TOKEN_SLASH: PREC_FACTOR,
}

func (p *Parser) getPrecedence(t ast.TokenType) int {
	if prec, ok := precedences[t]; ok {
		return prec
	}

	return PREC_NONE
}

func (p *Parser) ParseExpression(precedence int) ast.Expression {
	left := p.parsePrefix()

	for precedence < p.getPrecedence(p.peekToken.Tag) {
		p.nextToken()
		left = p.parseInfix(left)
	}

	return left
}

func (p *Parser) parsePrefix() ast.Expression {
	switch p.curToken.Tag {
	case ast.TOKEN_IDENTIFIER:
		return &ast.Identifier{Token: p.curToken, Value: p.curToken.Slice}
	case ast.TOKEN_INT:
		val, _ := strconv.ParseInt(p.curToken.Slice, 10, 64)

		return &ast.IntegerLiteral{Token: p.curToken, Value: val}
	case ast.TOKEN_FLOAT:
		val, _ := strconv.ParseFloat(p.curToken.Slice, 64)

		return &ast.FloatLiteral{Token: p.curToken, Value: val}
	case ast.TOKEN_STRING:
		return &ast.StringLiteral{Token: p.curToken, Value: p.curToken.Slice}
	case ast.TOKEN_KW_TRUE, ast.TOKEN_KW_FALSE:
		return &ast.BooleanLiteral{Token: p.curToken, Value: p.curToken.Tag == ast.TOKEN_KW_TRUE}
	case ast.TOKEN_MINUS:
		op := p.curToken.Slice

		p.nextToken()

		return &ast.PrefixExpression{Operator: op, Right: p.ParseExpression(PREC_UNARY)}
	case ast.TOKEN_LPAREN:
		p.nextToken()

		expr := p.ParseExpression(PREC_NONE)

		if p.peekToken.Tag == ast.TOKEN_RPAREN {
			p.nextToken()
		}

		return expr
	default: return nil
	}
}

func (p *Parser) parseInfix(left ast.Expression) ast.Expression {
	expr := &ast.InfixExpression{
		Left: left,
		Operator: p.curToken.Slice,
	}

	precedence := p.getPrecedence(p.curToken.Tag)

	p.nextToken()

	expr.Right = p.ParseExpression(precedence)

	return expr
}

func (p *Parser) parseExpressionList(end ast.TokenType) []ast.Expression {
  list := []ast.Expression{}

  if p.peekTokenIs(end) {
    p.nextToken()
    return list
  }

  p.nextToken()
  list = append(list, p.ParseExpression(PREC_ASSIGNMENT))

  for p.peekTokenIs(ast.TOKEN_COMMA) {
    p.nextToken()
    p.nextToken()
    list = append(list, p.ParseExpression(PREC_ASSIGNMENT))
  }

  if !p.expectPeek(end) { return nil }

  return list
}
