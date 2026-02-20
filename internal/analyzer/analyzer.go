package analyzer

import (
	"fmt"
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

func (a *Analyzer) Errors() []string {
	return a.errors
}

func (a *Analyzer) reportError(token ast.Token, format string, args ...interface{}) {
	msg := fmt.Sprintf(format, args...)
	fullMsg := fmt.Sprintf("Semantic Error at line %d, col %d: %s", token.Line, token.Col, msg)
	a.errors = append(a.errors, fullMsg)
}

func (a *Analyzer) Analyze(prog *ast.Program) error {
	for _, stmt := range prog.Statements {
		a.analyzeStatement(stmt)
	}

	if len(a.errors) > 0 {
		return fmt.Errorf("analysis finished with %d errors", len(a.errors))
	}

	return nil
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
