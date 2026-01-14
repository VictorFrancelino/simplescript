const std = @import("std");

pub const TokenType = enum {
  // Operators
  plus,
  minus,
  asterisk,
  slash,
  equals,
  comma,

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
  kw_if,
  kw_else,
  kw_true,
  kw_false,

  // Literals
  int,
  float,
  string,
  bool,
  identifier,

  // Special
  equal_equal,
  bang_equal,
  greater_equal,
  greater,
  less_equal,
  less,
  colon,
  eof,
  invalid,
};

pub const Token = struct {
  tag: TokenType,
  slice: []const u8,
  line: usize,
  col: usize,

  pub fn format(
    self: Token,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
  ) !void {
    _ = fmt;
    _ = options;
    try writer.print("{s}('{s}') at {d}:{d}", .{ @tagName(self.tag), self.slice, self.line, self.col });
  }
};

pub const Lexer = struct {
  buffer: []const u8,
  pos: usize = 0,
  line: usize = 1,
  col: usize = 1,
  peeked_token: ?Token = null,

  pub fn init(buffer: []const u8) Lexer {
    return .{ .buffer = buffer };
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

    const start_line = self.line;
    const start_col = self.col;
    const start_pos = self.pos;

    if (self.pos >= self.buffer.len) {
      return .{ .tag = .eof, .slice = "", .line = start_line, .col = start_col };
    }

    const char = self.advance();

    return switch (char) {
      '(' => self.makeSingleToken(.lparen, start_line, start_col),
      ')' => self.makeSingleToken(.rparen, start_line, start_col),
      '{' => self.makeSingleToken(.lbrace, start_line, start_col),
      '}' => self.makeSingleToken(.rbrace, start_line, start_col),
      '+' => self.makeSingleToken(.plus, start_line, start_col),
      '-' => self.makeSingleToken(.minus, start_line, start_col),
      '*' => self.makeSingleToken(.asterisk, start_line, start_col),
      '/' => blk: {
        if (self.peekChar(0) == '/') {
          while (self.pos < self.buffer.len and self.peekChar(0) != '\n') _ = self.advance();
          break :blk self.scanToken();
        }

        break :blk self.makeSingleToken(.slash, start_line, start_col);
      },
      '<' => blk: {
        if (self.peekChar(0) == '=') {
          _ = self.advance();
          break :blk .{ .tag = .less_equal, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
        }

        break :blk .{ .tag = .less, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
      },
      '>' => blk: {
        if (self.peekChar(0) == '=') {
          _ = self.advance();
          break :blk .{ .tag = .greater_equal, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
        }

        break :blk .{ .tag = .greater, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
      },
      ':' => self.makeSingleToken(.colon, start_line, start_col),
      ',' => self.makeSingleToken(.comma, start_line, start_col),
      '=' => blk: {
        if (self.peekChar(0) == '=') {
          _ = self.advance();
          break :blk .{ .tag = .equal_equal, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
        }

        break :blk .{ .tag = .equals, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
      },
      '!' => blk: {
        if (self.peekChar(0) == '=') {
          _ = self.advance();
          break :blk .{ .tag = .bang_equal, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
        }

        break :blk .{ .tag = .invalid, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
      },
      '.' => blk: {
        if (self.peekChar(0) == '.') {
          _ = self.advance();
          break :blk .{ .tag = .range, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
        }

        break :blk .{ .tag = .invalid, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col };
      },
      '\"' => self.scanString('\"', start_line, start_col),
      '\'' => self.scanString('\'', start_line, start_col),
      '0'...'9' => self.scanNumber(start_line, start_col),
      'a'...'z', 'A'...'Z', '_' => self.scanIdentifier(start_line, start_col),
      else => .{ .tag = .invalid, .slice = self.buffer[start_pos..self.pos], .line = start_line, .col = start_col }
    };
  }

  inline fn makeSingleToken(self: *Lexer, tag: TokenType, line: usize, col: usize) Token {
    const slice = self.buffer[self.pos - 1..self.pos];
    return .{ .tag = tag, .slice = slice, .line = line, .col = col };
  }

  fn skipWhitespace(self: *Lexer) void {
    while (self.pos < self.buffer.len) {
      const char = self.peekChar(0);
      switch (char) {
        ' ', '\t', '\r', '\n' => _ = self.advance(),
        else => break,
      }
    }
  }

  inline fn peekChar(self: *const Lexer, offset: usize) u8 {
    const target = self.pos + offset;
    return if (target < self.buffer.len) self.buffer[target] else 0;
  }

  fn scanString(self: *Lexer, delimiter: u8, start_line: usize, start_col: usize) Token {
    const content_start = self.pos;

    while (self.pos < self.buffer.len and self.peekChar(0) != delimiter) _ = self.advance();

    const content = self.buffer[content_start..self.pos];

    if (self.pos < self.buffer.len) _ = self.advance();

    return .{ .tag = .string, .slice = content, .line = start_line, .col = start_col };
  }

  fn scanNumber(self: *Lexer, start_line: usize, start_col: usize) Token {
    const start_pos = self.pos - 1;
    var is_float = false;

    while (self.pos < self.buffer.len) {
      const char = self.peekChar(0);
      if (char == '.') {
        if (self.peekChar(1) == '.') break;
        is_float = true;
        _ = self.advance();
      } else if (std.ascii.isDigit(char)) {
        _ = self.advance();
      }
      else break;
    }

    return .{
      .tag = if (is_float) .float else .int,
      .slice = self.buffer[start_pos..self.pos],
      .line = start_line,
      .col = start_col
    };
  }

  fn scanIdentifier(self: *Lexer, start_line: usize, start_col: usize) Token {
    const start_pos = self.pos - 1;

    while (self.pos < self.buffer.len) {
      const c = self.peekChar(0);
      if (std.ascii.isAlphanumeric(c) or c == '_') {
        _ = self.advance();
      } else break;
    }

    const slice = self.buffer[start_pos..self.pos];
    return .{ .tag = getKeyword(slice), .slice = slice, .line = start_line, .col = start_col };
  }

  // Keywords lookup - comptime for zero runtime cost
  fn getKeyword(text: []const u8) TokenType {
    const map = std.StaticStringMap(TokenType).initComptime(.{
      .{ "var", .kw_var },
      .{ "const", .kw_const },
      .{ "for", .kw_for },
      .{ "in", .kw_in },
      .{ "if", .kw_if },
      .{ "else", .kw_else },
      .{ "true", .kw_true },
      .{ "false", .kw_false },
    });
    return map.get(text) orelse .identifier;
  }

  fn advance(self: *Lexer) u8 {
    if (self.pos >= self.buffer.len) return 0;

    const char = self.buffer[self.pos];
    self.pos += 1;

    if (char == '\n') {
      self.line += 1;
      self.col = 1;
    } else self.col += 1;

    return char;
  }
};
