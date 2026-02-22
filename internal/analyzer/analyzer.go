package analyzer

import (
	"fmt"
	"os"

	"simplescript/internal/ast"
)

type Analyzer struct {
	env *Environment
	errors []string
}

func NewAnalyzer() *Analyzer {
	return &Analyzer {
		env: NewEnvironment(),
		errors: []string{},
	}
}

func MustAnalyze(prog *ast.Program) *ast.Program {
	a := NewAnalyzer()
	a.analyze(prog)

	if len(a.Errors()) > 0 {
		fmt.Println("Semantic Errors found:")
		for _, msg := range a.Errors() {
			fmt.Printf(" - %s\n", msg)
		}
		os.Exit(1)
	}

	return prog
}

func (a *Analyzer) analyze(prog *ast.Program) error {
	for _, stmt := range prog.Statements {
		a.analyzeStatement(stmt)
	}

	if len(a.errors) > 0 {
		return fmt.Errorf("analysis finished with %d errors", len(a.errors))
	}

	return nil
}

func (a *Analyzer) Errors() []string {
	return a.errors
}

func (a *Analyzer) reportError(token ast.Token, format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	fullMsg := fmt.Sprintf("Semantic Error at line %d, col %d: %s", token.Line, token.Col, msg)
	a.errors = append(a.errors, fullMsg)
}

func (a *Analyzer) analyzeStatement(stmt ast.Statement) {
	switch s := stmt.(type) {
	case *ast.VarDecl: a.analyzeVarDecl(s)
	case *ast.Assignment: a.analyzeAssignment(s)
	case *ast.Block: a.analyzeBlock(s)
	case *ast.IfStmt: a.analyzeIfStmt(s)
	case *ast.ForStmt: a.analyzeForStmt(s)
	case *ast.SayStmt: a.analyzeSayStmt(s)
	case *ast.ReturnStmt:
		if s.ReturnValue != nil {
			a.analyzeExpression(s.ReturnValue)
		}
	}
}
