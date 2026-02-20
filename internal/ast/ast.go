package ast

type TokenType int

const (
	// Operators
	TOKEN_PLUS TokenType = iota
	TOKEN_MINUS
	TOKEN_ASTERISK
	TOKEN_SLASH
	TOKEN_EQUALS
	TOKEN_COMMA
	TOKEN_DOT

	// Delimiters
	TOKEN_LPAREN
	TOKEN_RPAREN
	TOKEN_LBRACE
	TOKEN_RBRACE
	TOKEN_LBRACKET
	TOKEN_RBRACKET
	TOKEN_RANGE

	// Keywords
	TOKEN_KW_VAR
	TOKEN_KW_CONST
	TOKEN_KW_FOR
	TOKEN_KW_IN
	TOKEN_KW_IF
	TOKEN_KW_ELSE
	TOKEN_KW_TRUE
	TOKEN_KW_FALSE
	TOKEN_KW_CONTINUE
	TOKEN_KW_FUNC
	TOKEN_KW_RETURN
	TOKEN_KW_BREAK

	// Literals
	TOKEN_JSON
	TOKEN_STR
	TOKEN_INT
	TOKEN_FLOAT
	TOKEN_BOOL
	TOKEN_LIST
	TOKEN_MAP
	TOKEN_IDENTIFIER

	// Special
	TOKEN_EQUAL_EQUAL
	TOKEN_BANG_EQUAL
	TOKEN_GREATER_EQUAL
	TOKEN_GREATER
	TOKEN_LESS_EQUAL
	TOKEN_LESS
	TOKEN_COLON
	TOKEN_EOF
	TOKEN_INVALID
)

type Token struct {
  Tag TokenType
  Slice string
  Line int
  Col int
}

type Expression interface {
	expressionNode()
	String() string
}

type Statement interface {
	statementNode()
}

type Program struct {
	Statements []Statement
}

type VarDecl struct {
	Token Token
	IsConst bool
	Name string
	DataType string
	Value Expression
}

type Assignment struct {
	Token Token
	Targets []string
	Values  []Expression
}

type SayStmt struct {
	Token Token
	Args []Expression
}

type IfStmt struct {
	Token Token
	Condition Expression
	Consequence *Block
	Alternative Statement
}

type ForStmt struct {
	Token Token
	Iterator string
	Start Expression
	End Expression
	Body *Block
}

type Block struct {
	Token Token
	Statements []Statement
}

type IntegerLiteral struct{ Token Token; Value int64 }
type FloatLiteral struct{ Token Token; Value float64 }
type StringLiteral struct{ Token Token; Value string }
type BooleanLiteral struct{ Token Token; Value bool }
type Identifier struct{ Token Token; Value string }

func (il *IntegerLiteral) expressionNode() {}
func (il *IntegerLiteral) String() string { return "" }

func (fl *FloatLiteral) expressionNode() {}
func (fl *FloatLiteral) String() string { return "" }

func (sl *StringLiteral) expressionNode() {}
func (sl *StringLiteral) String() string { return "" }

func (bl *BooleanLiteral) expressionNode() {}
func (bl *BooleanLiteral) String() string { return "" }

func (i *Identifier) expressionNode() {}
func (i *Identifier) String() string { return "" }

type InfixExpression struct {
	Left Expression
	Operator string
	Right Expression
}
func (ie *InfixExpression) expressionNode() {}
func (ie *InfixExpression) String() string { return "" }

type PrefixExpression struct {
	Operator string
	Right Expression
}
func (pe *PrefixExpression) expressionNode() {}
func (pe *PrefixExpression) String() string { return "" }

func (p *Program) statementNode() {}
func (v *VarDecl) statementNode() {}
func (a *Assignment) statementNode() {}
func (s *SayStmt) statementNode() {}
func (i *IfStmt) statementNode() {}
func (f *ForStmt) statementNode() {}
func (b *Block) statementNode() {}
