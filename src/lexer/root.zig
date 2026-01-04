const std = @import("std");
pub const types = @import("types.zig");
const utils = @import("utils.zig");
const readers = @import("readers.zig");

pub const Lexer = struct {
  buffer: []const u8,
  pos: usize,

  pub fn init(buffer: []const u8) Lexer {
    return .{ .buffer = buffer, .pos = 0 };
  }

  pub fn next(self: *Lexer) types.Token {
    utils.skipWhitespace(self);

    if (self.pos >= self.buffer.len) return .{ .tag = .EOF, .slice = "" };

    const start = self.pos;
    const char = self.buffer[self.pos];

    switch (char) {
      '(' => { self.pos += 1; return .{ .tag = .LParen, .slice = "(" }; },
      ')' => { self.pos += 1; return .{ .tag = .RParen, .slice = ")" }; },
      '{' => { self.pos += 1; return .{ .tag = .LBrace, .slice = "{" }; },
      '}' => { self.pos += 1; return .{ .tag = .RBrace, .slice = "}" }; },
      '.' => {
        if (self.pos + 1 < self.buffer.len and self.buffer[self.pos + 1] == '.') {
          self.pos += 2;
          return .{ .tag = .Range, .slice = ".." };
        }

        self.pos += 1;
        return .{ .tag = .Invalid, .slice = "." };
      },
      '+' => { self.pos += 1; return .{ .tag = .Plus, .slice = "+" }; },
      '=' => { self.pos += 1; return .{ .tag = .Equals, .slice = "=" }; },
      '\'' => return readers.readString(self),
      '0'...'9' => return readers.readNumber(self),
      'a'...'z', 'A'...'Z', '_' => return readers.readIdentifier(self),
      else => {
        self.pos += 1;
        return .{ .tag = .Invalid, .slice = self.buffer[start..self.pos] };
      },
    }
  }
};
