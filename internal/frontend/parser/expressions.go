package parser

import (
	"strconv"

	"simplescript/internal/ast"
)

func (p *Parser) ParseExpression() ast.Expression {
	return p.parseEquality()
}

func (p *Parser) parseEquality() ast.Expression {
	expr := p.parseComparison()

	for p.match(ast.TOKEN_EQUAL_EQUAL, ast.TOKEN_BANG_EQUAL) {
		operator := p.previous()
		right := p.parseComparison()
		expr = &ast.InfixExpression{Left: expr, Operator: operator.Slice, Right: right}
	}
	return expr
}

func (p *Parser) parseComparison() ast.Expression {
	expr := p.parseTerm()

	for p.match(ast.TOKEN_LESS, ast.TOKEN_LESS_EQUAL, ast.TOKEN_GREATER, ast.TOKEN_GREATER_EQUAL) {
		operator := p.previous()
		right := p.parseTerm()
		expr = &ast.InfixExpression{Left: expr, Operator: operator.Slice, Right: right}
	}
	return expr
}

func (p *Parser) parseTerm() ast.Expression {
	expr := p.parseFactor()

	for p.match(ast.TOKEN_PLUS, ast.TOKEN_MINUS) {
		operator := p.previous()
		right := p.parseFactor()
		expr = &ast.InfixExpression{Left: expr, Operator: operator.Slice, Right: right}
	}
	return expr
}

func (p *Parser) parseFactor() ast.Expression {
	expr := p.parseUnary()

	for p.match(ast.TOKEN_ASTERISK, ast.TOKEN_SLASH) {
		operator := p.previous()
		right := p.parseUnary()
		expr = &ast.InfixExpression{Left: expr, Operator: operator.Slice, Right: right}
	}
	return expr
}

func (p *Parser) parseUnary() ast.Expression {
	if p.match(ast.TOKEN_MINUS) {
		operator := p.previous()
		right := p.parseUnary()
		return &ast.PrefixExpression{Operator: operator.Slice, Right: right}
	}
	return p.parseIndex()
}

func (p *Parser) parseIndex() ast.Expression {
	expr := p.parsePrimary()

	for {
		if p.match(ast.TOKEN_LBRACKET) {
			bracketToken := p.previous()
			indexExpr := p.ParseExpression()
			p.consume(ast.TOKEN_RBRACKET, "expected ']' after index")

			expr = &ast.IndexExpression{
				Token: bracketToken,
				Left: expr,
				Index: indexExpr,
			}
		} else {
			break
		}
	}

	return expr
}

func (p *Parser) parsePrimary() ast.Expression {
	if p.check(ast.TOKEN_EOF) {
		return nil
	}

	token := p.advance()

	switch token.Tag {
	case ast.TOKEN_INT:
		val, _ := strconv.ParseInt(token.Slice, 10, 64)
		return &ast.IntegerLiteral{Token: token, Value: val}
	case ast.TOKEN_FLOAT:
		val, _ := strconv.ParseFloat(token.Slice, 64)
		return &ast.FloatLiteral{Token: token, Value: val}
	case ast.TOKEN_STR:
		return &ast.StringLiteral{Token: token, Value: token.Slice}
	case ast.TOKEN_KW_TRUE:
		return &ast.BooleanLiteral{Token: token, Value: true}
	case ast.TOKEN_KW_FALSE:
		return &ast.BooleanLiteral{Token: token, Value: false}
	case ast.TOKEN_LBRACKET:
		elements := []ast.Expression{}

		if !p.check(ast.TOKEN_RBRACKET) {
			for {
				elements = append(elements, p.ParseExpression())

				if !p.match(ast.TOKEN_COMMA) { break }
			}
		}

		p.consume(ast.TOKEN_RBRACKET, "expected ']' after list elements")

		return &ast.ListLiteral{Token: token, Elements: elements}
	case ast.TOKEN_IDENTIFIER:
		return &ast.Identifier{Token: token, Value: token.Slice}
	case ast.TOKEN_LPAREN:
		expr := p.ParseExpression()
		p.consume(ast.TOKEN_RPAREN, "expected ')' after expression")
		return expr
	default:
		p.addError("unexpected token in expression")
		return nil
	}
}
