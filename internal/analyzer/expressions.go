package analyzer

import (
	"fmt"

	"simplescript/internal/ast"
)

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
	case *ast.PrefixExpression: return a.analyzePrefix(e)
	case *ast.InfixExpression: return a.analyzeInfix(e)
	}
	return "unknown"
}

func (a *Analyzer) analyzePrefix(node *ast.PrefixExpression) string {
	rightType := a.analyzeExpression(node.Right)

	if rightType == "unknown" { return "unknown" }

	switch node.Operator {
	case "-":
		if rightType != "int" && rightType != "float" {
			msg := fmt.Sprintf("invalid operation: cannot use '-' on type '%s'", rightType)
			a.errors = append(a.errors, msg)
		}
		return rightType
	case "!":
		if rightType != "bool" {
			msg := fmt.Sprintf("invalid operation: cannot use '!' on type '%s'", rightType)
			a.errors = append(a.errors, msg)
		}
		return "bool"
	}

	return "unknown"
}

func (a *Analyzer) analyzeInfix(node *ast.InfixExpression) string {
	leftType := a.analyzeExpression(node.Left)
	rightType := a.analyzeExpression(node.Right)

	if leftType == "unknown" || rightType == "unknown" {
		return "unknown"
	}

	if node.Operator == "==" || node.Operator == "!=" || node.Operator == "<" ||
		node.Operator == ">" || node.Operator == "<=" || node.Operator == ">=" {
		if leftType != rightType {
			msg := fmt.Sprintf("type mismatch: cannot compare '%s' with '%s'", leftType, rightType)
			a.errors = append(a.errors, msg)
		}

		return "bool"
	}

	if node.Operator == "+" || node.Operator == "-" || node.Operator == "*" || node.Operator == "/" {
		if leftType != rightType {
			msg := fmt.Sprintf(
				"type mismatch: invalid operation '%s %s %s'",
				leftType,
				node.Operator,
				rightType,
			)
			a.errors = append(a.errors, msg)
			return "unknown"
		}

		if leftType == "str" && node.Operator != "+" {
			msg := fmt.Sprintf("invalid operation: cannot use '%s' on strings", node.Operator)
			a.errors = append(a.errors, msg)
			return "unknown"
		}

		return leftType
	}

	return "unknown"
}
