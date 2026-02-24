package parser

import "simplescript/internal/ast"

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
		if token.Slice == "say" {
			return p.parseSay()
		}

		var target ast.Expression = &ast.Identifier{Token: token, Value: token.Slice}

		for p.match(ast.TOKEN_LBRACKET) {
			bracketToken := p.previous()
			indexExpr := p.ParseExpression()
			p.consume(ast.TOKEN_RBRACKET, "expected ']' after index")

			target = &ast.IndexExpression{
				Token: bracketToken,
				Left: target,
				Index: indexExpr,
			}
		}

		return p.parseAssignment(target)
	default:
		p.addError("unexpected token in statement")
		return nil
	}
}

func (p *Parser) parseVarDecl(isConst bool) ast.Statement {
	token := p.previous()

  name := p.consume(ast.TOKEN_IDENTIFIER, "expected variable name")
  if name.Tag == ast.TOKEN_INVALID { return nil }

  dataType := ""
  if p.match(ast.TOKEN_COLON) {
  	dt := p.advance()

    if dt.Tag == ast.TOKEN_EQUALS || dt.Tag == ast.TOKEN_EOF {
    	p.addError("expected type after ':'")
    	return nil
    }

    dataType = dt.Slice
  }

  if p.consume(ast.TOKEN_EQUALS, "expected '=' in variable declaration").Tag == ast.TOKEN_INVALID {
  	return nil
  }

  value := p.ParseExpression()

  return &ast.VarDecl{
		Token: token,
		Name: name.Slice,
		DataType: dataType,
		IsConst: isConst,
		Value: value,
	}
}

func (p *Parser) parseAssignment(firstTarget ast.Expression) ast.Statement {
	token := p.previous()
	targets := []ast.Expression{firstTarget}

  for p.match(ast.TOKEN_COMMA) {
  	target := p.parseIndex()

  	if target == nil {
   		p.addError("expected variable or list index after ','")
   		return nil
   	}

   	targets = append(targets, target)
  }

  var operator string

  if p.match(ast.TOKEN_EQUALS, ast.TOKEN_PLUS_EQUAL, ast.TOKEN_MINUS_EQUAL, ast.TOKEN_ASTERISK_EQUAL, ast.TOKEN_SLASH_EQUAL) {
  	operator = p.previous().Slice
  } else {
  	p.addError("expected assignment operator (=, +=, -=, *=, /=)")
   	return nil
  }

  if operator != "=" && (len(targets) > 1) {
  	p.addError("augmented assignment (" + operator + ") can only have one target")
  	return nil
  }

	values := []ast.Expression{}
  for {
    values = append(values, p.ParseExpression())

    if !p.match(ast.TOKEN_COMMA) {
    	break
    }
  }

  return &ast.Assignment{
		Token: token,
		Targets: targets,
		Operator: operator,
		Values: values,
	}
}

func (p *Parser) parseSay() ast.Statement {
	token := p.previous()

	if p.consume(ast.TOKEN_LPAREN, "expected '(' after 'say'").Tag == ast.TOKEN_INVALID {
		return nil
	}

	args := []ast.Expression{}
	if !p.check(ast.TOKEN_RPAREN) {
		for {
			args = append(args, p.ParseExpression())

			if !p.match(ast.TOKEN_COMMA) {
				break
			}
		}
	}

	if p.consume(ast.TOKEN_RPAREN, "expected ')' after arguments").Tag == ast.TOKEN_INVALID {
		return nil
	}

	return &ast.SayStmt{Token: token, Args: args}
}

func (p *Parser) parseBlock() *ast.Block {
	token := p.previous()
	stmts := []ast.Statement{}

	for !p.check(ast.TOKEN_RBRACE) && !p.isAtEnd() {
		if stmt := p.parseStatement(); stmt != nil {
			stmts = append(stmts, stmt)
		}
	}

	if p.consume(ast.TOKEN_RBRACE, "expected '}' after block").Tag == ast.TOKEN_INVALID {
		return nil
	}

	return &ast.Block{Token: token, Statements: stmts}
}

func (p *Parser) parseIf() ast.Statement {
	token := p.previous()
	cond := p.ParseExpression()

  if p.consume(ast.TOKEN_LBRACE, "expected '{' after if condition").Tag == ast.TOKEN_INVALID {
		return nil
	}

	cons := p.parseBlock()

	var alt ast.Statement
  if p.match(ast.TOKEN_KW_ELSE) {
    if p.match(ast.TOKEN_KW_IF) {
    	alt = p.parseIf()
    } else {
   		if p.consume(ast.TOKEN_LBRACE, "expected '{' after 'else'").Tag == ast.TOKEN_INVALID {
				return nil
			}

      alt = p.parseBlock()
    }
  }

  return &ast.IfStmt{
		Token: token,
		Condition: cond,
		Consequence: cons,
		Alternative: alt,
	}
}

func (p *Parser) parseFor() *ast.ForStmt {
	token := p.previous()

	iter := p.consume(ast.TOKEN_IDENTIFIER, "expected iterator variable name")
	if iter.Tag == ast.TOKEN_INVALID {
		return nil
	}

	if p.consume(ast.TOKEN_KW_IN, "expected 'in' after iterator variable").Tag == ast.TOKEN_INVALID {
		return nil
	}

	start := p.ParseExpression()

	if p.consume(ast.TOKEN_RANGE, "expected '..' after start value").Tag == ast.TOKEN_INVALID {
		return nil
	}

	end := p.ParseExpression()

	if p.consume(ast.TOKEN_LBRACE, "expected '{' after for loop range").Tag == ast.TOKEN_INVALID {
		return nil
	}

	body := p.parseBlock()

	return &ast.ForStmt{
		Token: token,
		Iterator: iter.Slice,
		Start: start,
		End: end,
		Body: body,
	}
}

func (p *Parser) parseReturn() ast.Statement {
	return &ast.ReturnStmt{
		Token: p.previous(),
		ReturnValue: p.ParseExpression(),
	}
}

func (p *Parser) parseBreak() ast.Statement {
	return &ast.BreakStmt{Token: p.previous()}
}

func (p *Parser) parseContinue() ast.Statement {
	return &ast.ContinueStmt{Token: p.previous()}
}
