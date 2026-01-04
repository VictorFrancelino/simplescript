const std = @import("std");
const root = @import("root.zig");

pub fn skipWhitespace(self: *root.Lexer) void {
  while (self.pos < self.buffer.len and std.ascii.isWhitespace(self.buffer[self.pos])) {
    self.pos += 1;
  }
}

pub fn isAlphaNumeric(c: u8) bool {
  return std.ascii.isAlphanumeric(c) or c == '_';
}
