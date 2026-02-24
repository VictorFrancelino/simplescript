package ast

type VarDecl struct {
	baseStmt
	Token Token
	IsConst bool
	Name string
	DataType string
	Value Expression
}

type Assignment struct {
	baseStmt
	Token Token
	Targets []string
	Values []Expression
}

type SayStmt struct {
	baseStmt
	Token Token
	Args []Expression
}

type IfStmt struct {
	baseStmt
	Token Token
	Condition Expression
	Consequence *Block
	Alternative Statement
}

type ForStmt struct {
	baseStmt
	Token Token
	Iterator string
	Start Expression
	End Expression
	Body *Block
}

type ReturnStmt struct {
	baseStmt
	Token Token
	ReturnValue Expression
}

type BreakStmt struct {
	baseStmt
	Token Token
}

type ContinueStmt struct {
	baseStmt
	Token Token
}

type Block struct {
	baseStmt
	Token Token
	Statements []Statement
}
