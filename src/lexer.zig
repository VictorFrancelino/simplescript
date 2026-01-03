const std = @import("std");

pub const TokenType = enum {
  Identifier, // ex: say, x, y
  String, // ex: 'Texto' (sem as aspas no valor)
  Number, // ex: 123
  LParen, // (
  RParen, // )
  Plus, // +
  EOF, // FIM DO ARQUIVO
  Invalid, // Caractere desconhecido
};

pub const Token = struct {
  tag: TokenType,
  slice: []const u8,
};

pub const Lexer = struct {
  buffer: []const u8,
  pos: usize,

  pub fn init(buffer: []const u8) Lexer {
    return .{ .buffer = buffer, .pos = 0 };
  }

  pub fn next(self: *Lexer) Token {
    self.skipWhitespace();

    if (self.pos >= self.buffer.len) return .{ .tag = .EOF, .slice = "" };

    const start = self.pos;
    const char = self.buffer[self.pos];

    // Roteamento baseado no primeiro caractere
    switch (char) {
      '(' => { self.pos += 1; return .{ .tag = .LParen, .slice = "(" }; },
      ')' => { self.pos += 1; return .{ .tag = .RParen, .slice = ")" }; },
      '+' => { self.pos += 1; return .{ .tag = .Plus, .slice = "+" }; },
      '\'' => return self.readString(),
      '0'...'9' => return self.readNumber(),
      'a'...'z', 'A'...'Z', '_' => return self.readIdentifier(),
      else => {
        self.pos += 1;
        return .{ .tag = .Invalid, .slice = self.buffer[start..self.pos] };
      }
    }
  }

  fn readString(self: *Lexer) Token {
    self.pos += 1;
    const start = self.pos;

    while (self.pos < self.buffer.len and self.buffer[self.pos] != '\'') self.pos += 1;

    const slice = self.buffer[start..self.pos];

    // Se não chegou no EOF, consome a aspa de fechamento
    if (self.pos < self.buffer.len) self.pos += 1;

    return .{ .tag = .String, .slice = slice };
  }

  fn readNumber(self: *Lexer) Token {
    const start = self.pos;
    while (self.pos < self.buffer.len and std.ascii.isDigit(self.buffer[self.pos])) self.pos += 1;
    return .{ .tag = .Number, .slice = self.buffer[start..self.pos] };
  }

  fn readIdentifier(self: *Lexer) Token {
    const start = self.pos;
    while (self.pos < self.buffer.len and isAlphaNumeric(self.buffer[self.pos])) self.pos += 1;
    return .{ .tag = .Identifier, .slice = self.buffer[start..self.pos] };
  }

  fn skipWhitespace(self: *Lexer) void {
    while (self.pos < self.buffer.len and std.ascii.isWhitespace(self.buffer[self.pos])) self.pos += 1;
  }

  fn isAlphaNumeric(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
  }
};
