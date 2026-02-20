package parser

import (
	"testing"

	"simplescript/internal/ast"
	"simplescript/internal/frontend/lexer"
)

func checkParserErrors(t *testing.T, p *Parser) {
	errors := p.Errors()
	if len(errors) == 0 {
		return
	}

	t.Errorf("parser has %d errors", len(errors))

	for _, msg := range errors {
		t.Errorf("parser error: %q", msg)
	}

	t.FailNow()
}

func TestVarStatements(t *testing.T) {
	tests := []struct {
		input string
		expectedIdentifier string
		expectedType string
		isConst bool
	}{
		{"var x: int = 5", "x", "int", false},
		{"const y: float = 3.14", "y", "float", true},
		{"var name = \"Victor\"", "name", "", false},
	}

	for _, tt := range tests {
		l := lexer.NewLexer(tt.input)
		p := NewParser(l)
		program, _ := p.Parse()
		checkParserErrors(t, p)

		if len(program.Statements) != 1 {
			t.Fatalf("program.Statements does not contain 1 statement. got=%d", len(program.Statements))
		}

		stmt := program.Statements[0]
		varDecl, ok := stmt.(*ast.VarDecl)
		if !ok {
			t.Fatalf("stmt not *ast.VarDecl. got=%T", stmt)
		}

		if varDecl.Name != tt.expectedIdentifier {
			t.Errorf("varDecl.Name not %s. got=%s", tt.expectedIdentifier, varDecl.Name)
		}

		if varDecl.IsConst != tt.isConst {
			t.Errorf("varDecl.IsConst not %t. got=%t", tt.isConst, varDecl.IsConst)
		}

		if tt.expectedType != "" && varDecl.DataType != tt.expectedType {
			t.Errorf("varDecl.DataType not %s. got=%s", tt.expectedType, varDecl.DataType)
		}
	}
}

func TestSayStatement(t *testing.T) {
	input := `say("hello", 10)`

	l := lexer.NewLexer(input)
	p := NewParser(l)
	program, _ := p.Parse()
	checkParserErrors(t, p)

	if len(program.Statements) != 1 {
		t.Fatalf("expected 1 statement, got=%d", len(program.Statements))
	}

	stmt, ok := program.Statements[0].(*ast.SayStmt)
	if !ok {
		t.Fatalf("stmt not *ast.SayStmt. got=%T", program.Statements[0])
	}

	if len(stmt.Args) != 2 {
		t.Errorf("expected 2 arguments, got=%d", len(stmt.Args))
	}
}

func TestIfElseStatement(t *testing.T) {
	input := `
		if x > 10 {
			say("major")
		} else {
			say("minor")
		}
	`
	l := lexer.NewLexer(input)
	p := NewParser(l)
	program, _ := p.Parse()
	checkParserErrors(t, p)

	stmt, ok := program.Statements[0].(*ast.IfStmt)
	if !ok {
		t.Fatalf("stmt not *ast.IfStmt. got=%T", program.Statements[0])
	}

	if stmt.Alternative == nil {
		t.Errorf("expected else (Alternative) to not be nil")
	}
}
