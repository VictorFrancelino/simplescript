const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const vm_mod = @import("vm.zig");
const OpCode = vm_mod.OpCode;
const Value = vm_mod.Value;
const Instruction = vm_mod.Instruction;

pub const Compiler = struct {
  instructions: std.ArrayListUnmanaged(u32) = .{},
  constants: std.ArrayListUnmanaged(Value) = .{},
  allocator: std.mem.Allocator,

  pub fn init(allocator: std.mem.Allocator) Compiler {
    return .{ .allocator = allocator };
  }

  pub fn deinit(self: *Compiler) void {
    self.instructions.deinit(self.allocator);
    self.constants.deinit(self.allocator);
  }

  // Adiciona um valor na tabela de constantes e retorna o índice (u16)
  fn addConstant(self: *Compiler, val: Value) !u16 {
    const idx = self.constants.items.len;
    try self.constants.append(self.allocator, val);
    return @as(u16, @intCast(idx));
  }

  // Gera uma instrução padrão de 3 argumentos (Op | RegA | ArgB | ArgC)
  fn emit(self: *Compiler, op: OpCode, a: u8, b: u8, c: u8) !void {
    const instr = @as(u32, @intFromEnum(op)) | (@as(u32, a) << 8) | (@as(u32, b) << 16) | (@as(u32, c) << 24);
    try self.instructions.append(self.allocator, instr);
  }

  // Gera uma instrução de carga de constante (Op | RegA | ConstIdx)
  fn emitLoad(self: *Compiler, op: OpCode, reg: u8, const_idx: u16) !void {
    const instr = @as(u32, @intFromEnum(op)) | (@as(u32, reg) << 8) | (@as(u32, const_idx) << 16);
    try self.instructions.append(self.allocator, instr);
  }

  // Helper para converter string token em i64
  fn parseInt(_: *Compiler, slice: []const u8) !i64 {
    return std.fmt.parseInt(i64, slice, 10);
  }

  pub fn compile(self: *Compiler, source: []const u8) !void {
    var lexer = Lexer.init(source);

    while (true) {
      const token = lexer.next();
      if (token.tag == .EOF) break;

      // Roteador de comandos
      if (token.tag == .Identifier and std.mem.eql(u8, token.slice, "say")) try self.compileSay(&lexer);
    }
    try self.emit(.Exit, 0, 0, 0);
  }

  fn compileSay(self: *Compiler, lexer: *Lexer) !void {
    _ = lexer.next(); // Consome '('

    const first_token = lexer.next();
    if (first_token.tag == .EOF) return;

    if (first_token.tag == .Number) {
      const val = try self.parseInt(first_token.slice);
      const idx = try self.addConstant(.{ .int = val });
      try self.emitLoad(.LoadConst, 0, idx);
    } else if (first_token.tag == .String) {
      const idx = try self.addConstant(.{ .string = first_token.slice });
      try self.emitLoad(.LoadConst, 0, idx);
    }

    while (true) {
      const next_token = lexer.next();

      if (next_token.tag == .Plus) {
        const operand_token = lexer.next();

        const val = try self.parseInt(operand_token.slice);
        const idx = try self.addConstant(.{ .int = val });

        try self.emitLoad(.LoadConst, 1, idx);
        try self.emit(.Add, 0, 0, 1);
      } else if (next_token.tag == .RParen) {
        break;
      } else {
        std.debug.print("Erro de sintaxe: esperado '+' ou ')'\n", .{});
        return;
      }
    }

    try self.emitLoad(.Say, 0, 0);
  }
};
