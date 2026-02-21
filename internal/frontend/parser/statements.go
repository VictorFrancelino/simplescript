package parser

import (
	"fmt"

	"simplescript/internal/ast"
)

func (p *Parser) parseStatement() ast.Statement {
	token := p.advance()

	switch token.Tag {
	case ast.TOKEN_KW_VAR: return p.parseVarDecl(false)
	case ast.TOKEN_KW_CONST: return p.parseVarDecl(true)
	case ast.TOKEN_KW_IF: return p.parseIf()
	case ast.TOKEN_KW_FOR: return p.parseFor()
	case ast.TOKEN_LBRACE: return p.parseBlock()
	case ast.TOKEN_KW_RETURN: return p.parseReturn()
	case ast.TOKEN_KW_BREAK: return p.parseBreak()
	case ast.TOKEN_KW_CONTINUE: return p.parseContinue()
	case ast.TOKEN_IDENTIFIER:
		if token.Slice == "say" { return p.parseSay() }
		return p.parseAssignment(token.Slice)
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

func (p *Parser) parseVarDecl(isConst bool) ast.Statement {
  stmt := &ast.VarDecl{Token: p.previous(), IsConst: isConst}

  nameToken := p.consume(ast.TOKEN_IDENTIFIER, "expected variable name")
  if nameToken.Tag == ast.TOKEN_INVALID {
  	return nil
  }
  stmt.Name = nameToken.Slice

  if p.match(ast.TOKEN_COLON) {
    typeToken := p.advance()

    if typeToken.Tag == ast.TOKEN_EQUALS || typeToken.Tag == ast.TOKEN_EOF {
    	msg := fmt.Sprintf(
     		"Syntax Error at line %d, col %d: expected type after ':'",
      	typeToken.Line,
      	typeToken.Col,
     	)
     	p.errors = append(p.errors, msg)
    	return nil
    }

    stmt.DataType = typeToken.Slice
  }

  if p.consume(ast.TOKEN_EQUALS, "expected '=' in variable declaration").Tag == ast.TOKEN_INVALID {
  	return nil
  }

  stmt.Value = p.ParseExpression(PREC_ASSIGNMENT)

  return stmt
}

func (p *Parser) parseAssignment(name string) ast.Statement {
  stmt := &ast.Assignment{Token: p.previous(), Targets: []string{name}}

  for p.match(ast.TOKEN_COMMA) {
  	targetToken := p.consume(ast.TOKEN_IDENTIFIER, "expected variable name after ','")

  	if targetToken.Tag == ast.TOKEN_INVALID {
   		return nil
   	}

   	stmt.Targets = append(stmt.Targets, targetToken.Slice)
  }

  if p.consume(ast.TOKEN_EQUALS, "expected '=' in assignment").Tag == ast.TOKEN_INVALID {
		return nil
	}

  stmt.Values = append(stmt.Values, p.ParseExpression(PREC_ASSIGNMENT))

  for p.match(ast.TOKEN_COMMA) {
    stmt.Values = append(stmt.Values, p.ParseExpression(PREC_ASSIGNMENT))
  }

  return stmt
}

func (p *Parser) parseSay() ast.Statement {
	stmt := &ast.SayStmt{Token: p.previous()}

	if p.consume(ast.TOKEN_LPAREN, "expected '(' after 'say'").Tag == ast.TOKEN_INVALID {
		return nil
	}

	stmt.Args = p.parseExpressionList(ast.TOKEN_RPAREN)

	return stmt
}

func (p *Parser) parseBlock() *ast.Block {
	block := &ast.Block{Token: p.previous()}

	for !p.check(ast.TOKEN_RBRACE) && !p.isAtEnd() {
		if stmt := p.parseStatement(); stmt != nil {
			block.Statements = append(block.Statements, stmt)
		}
	}

	if p.consume(ast.TOKEN_RBRACE, "expected '}' after block").Tag == ast.TOKEN_INVALID {
		return nil
	}

	return block
}

func (p *Parser) parseIf() ast.Statement {
  stmt := &ast.IfStmt{Token: p.previous()}

  stmt.Condition = p.ParseExpression(PREC_NONE)

  if p.consume(ast.TOKEN_LBRACE, "expected '{' after if condition").Tag == ast.TOKEN_INVALID {
		return nil
	}

  stmt.Consequence = p.parseBlock()

  if p.match(ast.TOKEN_KW_ELSE) {
    if p.match(ast.TOKEN_KW_IF) {
      stmt.Alternative = p.parseIf()
    } else {
   		if p.consume(ast.TOKEN_LBRACE, "expected '{' after 'else'").Tag == ast.TOKEN_INVALID {
				return nil
			}

      stmt.Alternative = p.parseBlock()
    }
  }

  return stmt
}

func (p *Parser) parseFor() *ast.ForStmt {
	stmt := &ast.ForStmt{Token: p.previous()}

	iterToken := p.consume(ast.TOKEN_IDENTIFIER, "expected iterator variable name")
	if iterToken.Tag == ast.TOKEN_INVALID {
		return nil
	}
	stmt.Iterator = iterToken.Slice

	if p.consume(ast.TOKEN_KW_IN, "expected 'in' after iterator variable").Tag == ast.TOKEN_INVALID {
		return nil
	}

	stmt.Start = p.ParseExpression(PREC_ASSIGNMENT)

	if p.consume(ast.TOKEN_RANGE, "expected '..' after start value").Tag == ast.TOKEN_INVALID {
		return nil
	}

	stmt.End = p.ParseExpression(PREC_ASSIGNMENT)

	if p.consume(ast.TOKEN_LBRACE, "expected '{' after for loop range").Tag == ast.TOKEN_INVALID {
		return nil
	}

	stmt.Body = p.parseBlock()

	return stmt
}

func (p *Parser) parseReturn() ast.Statement {
	stmt := &ast.ReturnStmt{Token: p.previous()}
	stmt.ReturnValue = p.ParseExpression(PREC_NONE)
	return stmt
}

func (p *Parser) parseBreak() ast.Statement {
	return &ast.BreakStmt{Token: p.previous()}
}

func (p *Parser) parseContinue() ast.Statement {
	return &ast.ContinueStmt{Token: p.previous()}
}
