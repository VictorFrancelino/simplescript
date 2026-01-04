const std = @import("std");
const root = @import("root.zig");
const types = @import("types.zig");

pub fn readString(self: *root.Lexer) types.Token {
  self.pos += 1;
  const start = self.pos;
  while (self.pos < self.buffer.len and self.buffer[self.pos] != '\'') self.pos += 1;
  const slice = self.buffer[start..self.pos];
  if (self.pos < self.buffer.len) self.pos += 1;
  return .{ .tag = .String, .slice = slice };
}

pub fn readNumber(self: *root.Lexer) types.Token {
  const start = self.pos;
  while (self.pos < self.buffer.len and std.ascii.isDigit(self.buffer[self.pos])) self.pos += 1;
  return .{ .tag = .Number, .slice = self.buffer[start..self.pos] };
}

pub fn readIdentifier(self: *root.Lexer) types.Token {
  const start = self.pos;
  const utils = @import("utils.zig");
  while (self.pos < self.buffer.len and utils.isAlphaNumeric(self.buffer[self.pos])) self.pos += 1;
  const slice = self.buffer[start..self.pos];

  if (std.mem.eql(u8, slice, "var")) return .{ .tag = .Var, .slice = slice };
  if (std.mem.eql(u8, slice, "const")) return .{ .tag = .Const, .slice = slice };
  if (std.mem.eql(u8, slice, "for")) return .{ .tag = .For, .slice = slice };
  if (std.mem.eql(u8, slice, "in")) return .{ .tag = .In, .slice = slice };

  return .{ .tag = .Identifier, .slice = slice };
}
