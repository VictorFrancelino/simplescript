const std = @import("std");
const root = @import("root.zig");
const Lexer = @import("../lexer/root.zig").Lexer;
const Token = @import("../lexer/types.zig").Token;

pub fn compile(self: *root.Compiler, source: []const u8) anyerror!void {
  var lexer = Lexer.init(source);
  while (true) {
    const token = lexer.next();
    if (token.tag == .EOF) break;
    try self.compileStatement(&lexer, token);
  }
  try self.emit(.Exit, 0, 0, 0);
}

pub fn compileStatement(self: *root.Compiler, lexer: *Lexer, token: Token) anyerror!void {
  switch (token.tag) {
    .Var => try compileDeclaration(self, lexer, false),
    .Const => try compileDeclaration(self, lexer, true),
    .For => try compileForLoop(self, lexer),
    .Identifier => {
      if (std.mem.eql(u8, token.slice, "say")) {
        try self.compileSay(lexer);
      } else {}
    },
    .RBrace => {},
    else => return error.UnexpectedToken,
  }
}

fn compileDeclaration(self: *root.Compiler, lexer: *Lexer, is_const: bool) !void {
  const name_token = lexer.next();

  const next_token = lexer.next();
  if (next_token.tag != .Equals) return error.ExpectedEquals;

  const value_token = lexer.next();
  const val = try std.fmt.parseInt(i64, value_token.slice, 10);
  const idx = try self.addConstant(.{ .int = val });

  const reg = self.next_register;
  try self.emitLoad(.LoadConst, reg, idx);

  const name_copy = try self.allocator.dupe(u8, name_token.slice);

  try self.locals.put(name_copy, .{ .reg = reg, .is_const = is_const });

  self.next_register += 1;
}

pub fn compileSay(self: *root.Compiler, lexer: *Lexer) !void {
  _ = lexer.next();

  const first_token = lexer.next();
  if (first_token.tag == .EOF) return;

  try loadValueToReg(self, 0, first_token);

  while (true) {
    const next_token = lexer.next();

    if (next_token.tag == .Plus) {
      const operand_token = lexer.next();

      try loadValueToReg(self, 1, operand_token);

      try self.emit(.Add, 0, 0, 1);
    } else if (next_token.tag == .RParen) {
      break;
    } else {
      std.debug.print("Erro de sintaxe no say: Token inesperado '{s}'\n", .{next_token.slice});
      return error.SyntaxError;
    }
  }

  try self.emitLoad(.Say, 0, 0);
}

fn compileForLoop(self: *root.Compiler, lexer: *Lexer) anyerror!void {
  const name_token = lexer.next();
  _ = lexer.next();

  const start_token = lexer.next();
  const start_val = try std.fmt.parseInt(i64, start_token.slice, 10);
  const start_idx = try self.addConstant(.{ .int = start_val });
  const iterator_reg = self.next_register;
  try self.emitLoad(.LoadConst, iterator_reg, start_idx);

  const name_copy = try self.allocator.dupe(u8, name_token.slice);
  try self.locals.put(name_copy, .{ .reg = iterator_reg, .is_const = false });
  self.next_register += 1;

  _ = lexer.next();
  const end_token = lexer.next();
  const end_val = try std.fmt.parseInt(i64, end_token.slice, 10);
  const end_idx = try self.addConstant(.{ .int = end_val });
  const limit_reg = self.next_register;
  try self.emitLoad(.LoadConst, limit_reg, end_idx);
  self.next_register += 1;

  _ = lexer.next();

  const loop_start = self.instructions.items.len;

  const cond_reg = self.next_register;
  try self.emit(.LessThan, cond_reg, iterator_reg, limit_reg);

  const jump_exit_index = self.instructions.items.len;
  try self.emitLoad(.JumpIfFalse, cond_reg, 0);

  while (true) {
    const token = lexer.next();
    if (token.tag == .RBrace) break;
    if (token.tag == .EOF) return error.UnexpectedEOF;

    try self.compileStatement(lexer, token);
  }

  const one_idx = try self.addConstant(.{ .int = 1 });
  const one_reg = self.next_register;
  try self.emitLoad(.LoadConst, one_reg, one_idx);

  try self.emit(.Add, iterator_reg, iterator_reg, one_reg);

  try self.emitLoad(.Jump, 0, @as(u16, @intCast(loop_start)));

  const loop_end = self.instructions.items.len;
  self.patchJump(jump_exit_index, loop_end);
}

fn loadValueToReg(self: *root.Compiler, reg: u8, token: Token) !void {
  switch (token.tag) {
    .Number => {
      const val = try self.parseInt(token.slice);
      const idx = try self.addConstant(.{ .int = val });
      try self.emitLoad(.LoadConst, reg, idx);
    },
    .Identifier => {
      if (self.locals.get(token.slice)) |local| {
        try self.emit(.Move, reg, local.reg, 0);
      } else {
        std.debug.print("Erro: Variavel '{s}' nao definida.\n", .{token.slice});
        return error.UndefinedVariable;
      }
    },
    .String => {
      const idx = try self.addConstant(.{ .string = token.slice });
      try self.emitLoad(.LoadConst, reg, idx);
    },
    else => return error.InvalidExpression,
  }
}
