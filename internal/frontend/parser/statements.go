package parser

import "simplescript/internal/ast"

func (p *Parser) parseStatement() ast.Statement {
	switch p.curToken.Tag {
	case ast.TOKEN_KW_VAR: return p.parseVarDecl(false)
	case ast.TOKEN_KW_CONST: return p.parseVarDecl(true)
	case ast.TOKEN_KW_IF: return p.parseIf()
	case ast.TOKEN_KW_FOR: return p.parseFor()
	case ast.TOKEN_LBRACE: return p.parseBlock()
	case ast.TOKEN_KW_RETURN: return p.parseReturn()
	case ast.TOKEN_KW_BREAK: return p.parseBreak()
	case ast.TOKEN_KW_CONTINUE: return p.parseContinue()
	case ast.TOKEN_IDENTIFIER:
		if p.curToken.Slice == "say" { return p.parseSay() }

		return p.parseAssignment(p.curToken.Slice)
	default: return nil
	}
}

func (p *Parser) parseVarDecl(isConst bool) ast.Statement {
  stmt := &ast.VarDecl{Token: p.curToken, IsConst: isConst}

  if !p.expectPeek(ast.TOKEN_IDENTIFIER) { return nil }

  stmt.Name = p.curToken.Slice

  if p.peekTokenIs(ast.TOKEN_COLON) {
    p.nextToken()
    p.nextToken()
    stmt.DataType = p.curToken.Slice
  }

  if !p.expectPeek(ast.TOKEN_EQUALS) { return nil }
  p.nextToken()
  stmt.Value = p.ParseExpression(PREC_ASSIGNMENT)

  return stmt
}

func (p *Parser) parseAssignment(name string) ast.Statement {
  stmt := &ast.Assignment{Token: p.curToken, Targets: []string{name}}

  for p.peekTokenIs(ast.TOKEN_COMMA) {
  	p.nextToken()

  	if !p.expectPeek(ast.TOKEN_IDENTIFIER) {
   		return nil
   	}

   	stmt.Targets = append(stmt.Targets, p.curToken.Slice)
  }

  if !p.expectPeek(ast.TOKEN_EQUALS) { return nil }

  p.nextToken()

  stmt.Values = append(stmt.Values, p.ParseExpression(PREC_ASSIGNMENT))

  for p.peekTokenIs(ast.TOKEN_COMMA) {
    p.nextToken()
    p.nextToken()

    stmt.Values = append(stmt.Values, p.ParseExpression(PREC_ASSIGNMENT))
  }

  return stmt
}

func (p *Parser) parseSay() ast.Statement {
	stmt := &ast.SayStmt{Token: p.curToken}

	if !p.expectPeek(ast.TOKEN_LPAREN) { return nil }

	stmt.Args = p.parseExpressionList(ast.TOKEN_RPAREN)

	return stmt
}

func (p *Parser) parseBlock() *ast.Block {
	block := &ast.Block{Token: p.curToken}

	p.nextToken()

	for !p.curTokenIs(ast.TOKEN_RBRACE) && !p.curTokenIs(ast.TOKEN_EOF) {
		if stmt := p.parseStatement(); stmt != nil {
			block.Statements = append(block.Statements, stmt)
		}

		p.nextToken()
	}

	return block
}

func (p *Parser) parseIf() ast.Statement {
  stmt := &ast.IfStmt{Token: p.curToken}

  p.nextToken()

  stmt.Condition = p.ParseExpression(PREC_NONE)

  if !p.expectPeek(ast.TOKEN_LBRACE) { return nil }

  stmt.Consequence = p.parseBlock()

  if p.peekTokenIs(ast.TOKEN_KW_ELSE) {
  	p.nextToken()

    if p.peekTokenIs(ast.TOKEN_KW_IF) {
    	p.nextToken()
      stmt.Alternative = p.parseIf()
    } else {
    	if !p.expectPeek(ast.TOKEN_LBRACE) { return nil }

      stmt.Alternative = p.parseBlock()
    }
  }

  return stmt
}

func (p *Parser) parseFor() *ast.ForStmt {
	stmt := &ast.ForStmt{Token: p.curToken}

	if !p.expectPeek(ast.TOKEN_IDENTIFIER) { return nil }

	stmt.Iterator = p.curToken.Slice

	if !p.expectPeek(ast.TOKEN_KW_IN) { return nil }

	p.nextToken()

	stmt.Start = p.ParseExpression(PREC_ASSIGNMENT)

	if !p.expectPeek(ast.TOKEN_RANGE) { return nil }

	p.nextToken()

	stmt.End = p.ParseExpression(PREC_ASSIGNMENT)

	if !p.expectPeek(ast.TOKEN_LBRACE) { return nil }

	stmt.Body = p.parseBlock()

	return stmt
}

func (p *Parser) parseReturn() ast.Statement {
	stmt := &ast.ReturnStmt{Token: p.curToken}

	p.nextToken()

	stmt.ReturnValue = p.ParseExpression(PREC_NONE)

	return stmt
}

func (p *Parser) parseBreak() ast.Statement {
	return &ast.BreakStmt{Token: p.curToken}
}

func (p *Parser) parseContinue() ast.Statement {
	return &ast.ContinueStmt{Token: p.curToken}
}
