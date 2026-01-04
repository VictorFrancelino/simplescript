pub const TokenType = enum {
  Const,
  Equals,
  For,
  In,
  Invalid,
  Range,
  LBrace,
  RBrace,
  Identifier,
  Var,
  String,
  Number,
  LParen,
  RParen,
  Plus,
  EOF,
};

pub const Token = struct {
  tag: TokenType,
  slice: []const u8,
};
