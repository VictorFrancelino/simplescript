package analyzer

import "simplescript/internal/ast"

func (a *Analyzer) analyzeVarDecl(node *ast.VarDecl) {
	if _, exists := a.env.store[node.Name]; exists {
		a.reportError(
			node.Token,
			"variable '%s' is already defined in this scope",
			node.Name,
		)
		return
	}

	if node.DataType == "" {
		a.reportError(
			node.Token,
			"explicit type declaration is required for variable '%s' (e.g., '%s: int')",
			node.Name,
			node.Name,
		)
		return
	}

	valueType := a.analyzeExpression(node.Value)

	if node.DataType != valueType && valueType != "unknown" {
		a.reportError(
			node.Token,
			"type mismatch: cannot assign type '%s' to variable of type '%s'",
			valueType,
			node.DataType,
		)
	}

	a.env.Define(node.Name, node.DataType)
}

func (a *Analyzer) analyzeAssignment(node *ast.Assignment) {
	for _, target := range node.Targets {
		_, exists := a.env.Resolve(target)
		if !exists {
			a.reportError(node.Token, "undefined variable '%s'", target)
		}
	}

	for _, val := range node.Values {
		a.analyzeExpression(val)
	}
}

func (a *Analyzer) analyzeBlock(node *ast.Block) {
	previousEnv := a.env
	a.env = NewEnclosedEnvironment(previousEnv)

	for _, stmt := range node.Statements {
		a.analyzeStatement(stmt)
	}

	a.env = previousEnv
}

func (a *Analyzer) analyzeSayStmt(node *ast.SayStmt) {
	for _, arg := range node.Args {
		a.analyzeExpression(arg)
	}
}

func (a *Analyzer) analyzeIfStmt(node *ast.IfStmt) {
	conditionType := a.analyzeExpression(node.Condition)

	if conditionType != "bool" && conditionType != "unknown" {
		a.reportError(
			node.Token,
			"condition in 'if' statement must evaluate to a boolean, got '%s'",
			conditionType,
		)
	}

	a.analyzeBlock(node.Consequence)

	if node.Alternative != nil {
		a.analyzeStatement(node.Alternative)
	}
}

func (a *Analyzer) analyzeForStmt(node *ast.ForStmt) {
	previousEnv := a.env
	a.env = NewEnclosedEnvironment(previousEnv)

	a.env.Define(node.Iterator, "int")

	a.analyzeExpression(node.Start)
	a.analyzeExpression(node.End)

	a.analyzeBlock(node.Body)

	a.env = previousEnv
}
