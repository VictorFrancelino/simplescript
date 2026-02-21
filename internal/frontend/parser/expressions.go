package parser

import (
	"fmt"
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
	if left == nil {
		return nil
	}

	for precedence < p.getPrecedence(p.current().Tag) {
		p.advance()
		left = p.parseInfix(left)
	}

	return left
}

func (p *Parser) parsePrefix() ast.Expression {
	token := p.advance()

	switch token.Tag {
	case ast.TOKEN_IDENTIFIER: return &ast.Identifier{Token: token, Value: token.Slice}
	case ast.TOKEN_INT:
		val, _ := strconv.ParseInt(token.Slice, 10, 64)
		return &ast.IntegerLiteral{Token: token, Value: val}
	case ast.TOKEN_FLOAT:
		val, _ := strconv.ParseFloat(token.Slice, 64)
		return &ast.FloatLiteral{Token: token, Value: val}
	case ast.TOKEN_STR: return &ast.StringLiteral{Token: token, Value: token.Slice}
	case ast.TOKEN_KW_TRUE, ast.TOKEN_KW_FALSE: return &ast.BooleanLiteral{Token: token, Value: token.Tag == ast.TOKEN_KW_TRUE}
	case ast.TOKEN_MINUS:
		right := p.ParseExpression(PREC_UNARY)
		return &ast.PrefixExpression{Operator: token.Slice, Right: right}
	case ast.TOKEN_LPAREN:
		expr := p.ParseExpression(PREC_NONE)

		if p.consume(ast.TOKEN_RPAREN, "expected ')' after expression").Tag == ast.TOKEN_INVALID {
			return nil
		}

		return expr
	default:
		msg := fmt.Sprintf(
			"Syntax Error at line %d, col %d: unexpected token '%s'",
			token.Line,
			token.Col,
			token.Slice,
		)
		p.errors = append(p.errors, msg)
		return nil
	}
}

func (p *Parser) parseInfix(left ast.Expression) ast.Expression {
	opToken := p.previous()

	expr := &ast.InfixExpression{
		Left: left,
		Operator: opToken.Slice,
	}

	precedence := p.getPrecedence(opToken.Tag)
	expr.Right = p.ParseExpression(precedence)

	return expr
}

func (p *Parser) parseExpressionList(end ast.TokenType) []ast.Expression {
  list := []ast.Expression{}

  if p.check(end) {
    p.advance()
    return list
  }

  list = append(list, p.ParseExpression(PREC_ASSIGNMENT))

  for p.match(ast.TOKEN_COMMA) {
    list = append(list, p.ParseExpression(PREC_ASSIGNMENT))
  }

  if p.consume(end, "expected closing delimiter").Tag == ast.TOKEN_INVALID {
  	return nil
  }

  return list
}
