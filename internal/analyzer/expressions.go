package analyzer

import "simplescript/internal/ast"

func (a *Analyzer) analyzeExpression(expr ast.Expression) string {
	switch e := expr.(type) {
	case *ast.IntegerLiteral:
		return "int"
	case *ast.FloatLiteral:
		return "float"
	case *ast.StringLiteral:
		return "str"
	case *ast.BooleanLiteral:
		return "bool"
	case *ast.Identifier:
		if dataType, exists := a.env.Resolve(e.Value); exists {
			return dataType
		}
		a.reportError(e.Token, "undefined variable '%s'", e.Value)
		return "unknown"
	}
	return "unknown"
}
