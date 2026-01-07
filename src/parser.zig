const std = @import("std");

pub const TokenType = enum {
  // Operators
  plus,
  minus,
  asterisk,
  slash,
  equals,

  // Delimiters
  lparen,
  rparen,
  lbrace,
  rbrace,
  range,

  // Keywords
  kw_var,
  kw_const,
  kw_for,
  kw_in,

  // Literals
  number,
  string,
  identifier,

  // Special
  eof,
  invalid,
};

pub const Token = struct {
  tag: TokenType,
  slice: []const u8,

  pub fn format(
    self: Token,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
  ) !void {
    _ = fmt;
    _ = options;
    try writer.print("{s}('{s}')", .{ @tagName(self.tag), self.slice });
  }
};

pub const Lexer = struct {
  buffer: []const u8,
  pos: usize = 0,
  peeked_token: ?Token = null,

  pub fn init(buffer: []const u8) Lexer {
    .{ .buffer = buffer };
  }

  // Get next token, consuming it
  pub fn next(self: *Lexer) Token {
    if (self.peeked_token) |token| {
      self.peeked_token = null;
      return token;
    }
    return self.scanToken();
  }

  // Peek at next token without consuming
  pub fn peek(self: *Lexer) Token {
    if (self.peeked_token) |token| return token;
    const token = self.scanToken();
    self.peeked_token = token;
    return token;
  }

  fn scanToken(self: *Lexer) Token {
    self.skipWhitespace();
    if (self.pos >= self.buffer.len) return .{ .tag = .EOF, .slice = "" };

    const start = self.pos;
    const char = self.buffer[self.pos];

    return switch (char) {
      '(' => self.makeSingleToken(.lparen),
      ')' => self.makeSingleToken(.rparen),
      '{' => self.makeSingleToken(.lbrace),
      '}' => self.makeSingleToken(.rbrace),
      '+' => self.makeSingleToken(.plus),
      '-' => self.makeSingleToken(.minus),
      '*' => self.makeSingleToken(.asterisk),
      '/' => self.makeSingleToken(.slash),
      '=' => self.makeSingleToken(.equals),
      '.' => blk: {
        if (self.peekChar(1) == '.') {
          self.pos += 2;
          break :blk .{ .tag = .range, .slice = self.buffer[start..self.pos] };
        }
        self.pos += 1;
        break :blk .{ .tag = .invalid, .slice = self.buffer[start..self.pos] };
      },
      '\'' => self.scanString(),
      '0'...'9' => self.scanNumber(),
      'a'...'z', 'A'...'Z', '_' => self.scanIdentifier(),
      else => self.makeSingleToken(.invalid),
    };
  }

  inline fn makeSingleToken(self: *Lexer, tag: TokenType) Token {
    const slice = self.buffer[self.pos..][0..1];
    self.pos += 1;
    return .{ .tag = tag, .slice = slice };
  }

  fn skipWhitespace(self: *Lexer) void {
    while (self.pos < self.buffer.len) {
      switch (self.buffer[self.pos]) {
        ' ', '\t', '\r', '\n' => self.pos += 1,
        else => break,
      }
    }
  }

  inline fn peekChar(self: *const Lexer, offset: usize) u8 {
    const target = self.pos + offset;
    return if (target < self.buffer.len) self.buffer[target] else 0;
  }

  fn scanString(self: *Lexer) Token {
    _ = self.pos;
    self.pos += 1; // Skip opening quote

    const content_start = self.pos;

    // Find closing quote
    while (self.pos < self.buffer.len and self.buffer[self.pos] != '\'') self.pos += 1;

    const content = self.buffer[content_start..self.pos];

    // Skip closing quote if present
    if (self.pos < self.buffer.len) self.pos += 1;

    return .{ .tag = .string, .slice = content };
  }

  fn scanNumber(self: *Lexer) Token {
    const start = self.pos;

    // Integer part
    while (self.pos < self.buffer.len and std.ascii.isDigit(self.buffer[self.pos])) self.pos += 1;

    return .{ .tag = .number, .slice = self.buffer[start..self.pos] };
  }

  fn scanIdentifier(self: *Lexer) Token {
    const start = self.pos;

    // First character already checked in scanToken
    self.pos += 1;

    // Continue while alphanumeric or underscore
    while (self.pos < self.buffer.len) {
      const char = self.buffer[self.pos];
      if (std.ascii.isAlphanumeric(char) or char == '_') {
        self.pos += 1;
      } else break;
    }

    const slice = self.buffer[start..self.pos];
    const tag = getKeyword(slice);

    return .{ .tag = tag, .slice = slice };
  }

  // Keywords lookup - comptime for zero runtime cost
  fn getKeyword(text: []const u8) TokenType {
    const map = std.StaticStringMap(TokenType).initComptime(.{
      .{ "var", .kw_var },
      .{ "const", .kw_const },
      .{ "for", .kw_for },
      .{ "in", .kw_in },
    });
    return map.get(text) orelse .identifier;
  }
};
