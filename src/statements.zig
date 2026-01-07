const std = @import("std");
const compiler_mod = @import("compiler.zig");
const parser_mod = @import("parser.zig");
const expressions_mod = @import("expressions.zig");
const llvm_bindings = @import("llvm.zig");

const Compiler = compiler_mod.Compiler;
const Lexer = parser_mod.Lexer;
const Token = parser_mod.Token;
const TokenType = parser_mod.TokenType;
const llvm = llvm_bindings.c;

// Compile entire source code
pub fn compile(self: *Compiler, source: []const u8) !void {
  var lexer = Lexer.init(source);

  while (true) {
    const token = lexer.next();
    if (token.tag == .eof) break;
    try self.compileStatement(self, &lexer, token);
  }
}

// Compile a single statement
pub fn compileStatement(self: *Compiler, lexer: *Lexer, token: Token) !void {
  switch (token.tag) {
    .kw_var => try compileDeclaration(self, lexer, false),
    .kw_const => try compileDeclaration(self, lexer, true),
    .kw_for => try compileForLoop(self, lexer),
    .Identifier => {
      // Check for built-in functions
      if (std.mem.eql(u8, token.slice, "say")) {
        try compileSay(self, lexer);
      } else {
        std.debug.print("Error: Unknown identifier '{s}'\n", .{token.slice});
        return error.UnknownIdentifier;
      }
    },
    .rbrace => {}, // Valid but no-op (closing brace of block)
    else => {
      std.debug.print("Error: Unexpected token {} at statement level\n", .{token});
      return error.UnexpectedToken;
    },
  }
}

fn compileDeclaration(self: *Compiler, lexer: *Lexer, is_const: bool) !void {
  const name_token = lexer.next();
  if (name_token.tag != .identifier) {
    std.debug.print("Error: Expected identifier after {s}, got {}\n", .{ if (is_const) "const" else "var", name_token });
    return error.ExpectedIdentifier;
  }

  const equals_token = lexer.next();
  if (equals_token.tag != .equals) {
    std.debug.print("Error: Expected '=' after identifier, got {}\n", .{equals_token});
    return error.ExpectedEquals;
  }

  // Parse the initialization expression
  const llvm_val = try expressions_mod.parseExpression(self, lexer);

  // Allocate stack space for the variable
  const i64_type = llvm.LLVMInt64TypeInContext(self.context);
  const ptr = llvm.LLVMBuildAlloca(self.builder, i64_type, name_token.slice.ptr);
  _ = llvm.LLVMBuildStore(self.builder, llvm_val, ptr);

  // Store in symbol table
  const name_copy = try self.allocator.dupe(u8, name_token.slice);
  try self.locals.put(name_copy, .{ .llvm_value = ptr, .is_const = is_const });
}

// Compile say() function call
pub fn compileSay(self: *Compiler, lexer: *Lexer) !void {
  // Expect '('
  const lparen = lexer.next();
  if (lparen.tag != .lparen) {
    std.debug.print("Error: Expected '(' after 'say', got {}\n", .{lparen});
    return error.ExpectedLParen;
  }

  // Parse expression argument
  const value = try expressions_mod.parseExpression(self, lexer);

  // Expect ')'
  const rparen = lexer.next();
  if (rparen.tag != .rparen) {
    std.debug.print("Error: Expected ')' after expression, got {}\n", .{rparen});
    return error.ExpectedRParen;
  }

  // Generate print call
  try self.printInt(value);
}

// Compile for loop: for i in start...end { body }
fn compileForLoop(self: *Compiler, lexer: *Lexer) !void {
  const i64_type = llvm.LLVMInt64TypeInContext(self.context);

  // Get iterator variable name
  const name_token = lexer.next();
  if (name_token.tag != .identifier) {
    std.debug.print("Error: Expected identifier after 'for', got {}\n", .{name_token});
    return error.ExpectedIdentifier;
  }

  // Expect 'in' keyword
  const in_token = lexer.next();
  if (in_token.tag != .kw_in) {
    std.debug.print("Error: Expected 'in' after loop variable, got {}\n", .{in_token});
    return error.ExpectedIn;
  }

  // Parse start value
  const start_token = lexer.next();
  if (start_token.tag != .number) {
    std.debug.print("Error: Expected number for loop start, got {}\n", .{start_token});
    return error.ExpectedNumber;
  }
  const start_val = try std.fmt.parseInt(i64, start_token.slice, 10);
  const llvm_start = llvm.LLVMConstInt(i64_type, @bitCast(start_val), 0);

  // Expect range operator '..'
  const range_token = lexer.next();
  if (range_token.tag != .range) {
    std.debug.print("Error: Expected '..' in for loop, got {}\n", .{range_token});
    return error.ExpectedRange;
  }

  // Parse end value
  const end_token = lexer.next();
  if (end_token.tag != .number) {
    std.debug.print("Error: Expected number for loop end, got {}\n", .{end_token});
    return error.ExpectedNumber;
  }
  const end_val = try std.fmt.parseInt(i64, end_token.slice, 10);
  const llvm_end = llvm.LLVMConstInt(i64_type, @bitCast(end_val), 0);

  // Expect '{'
  const lbrace = lexer.next();
  if (lbrace.tag != .lbrace) {
    std.debug.print("Error: Expected '{{' to start loop body, got {}\n", .{lbrace});
    return error.ExpectedLBrace;
  }

  // Allocate loop variable and initialize
  const iter_ptr = llvm.LLVMBuildAlloca(self.builder, i64_type, name_token.slice.ptr);
  _ = llvm.LLVMBuildStore(self.builder, llvm_start, iter_ptr);

  // Add to symbol table (mutable)
  const name_copy = try self.allocator.dupe(u8, name_token.slice);
  try self.locals.put(name_copy, .{
    .llvm_value = iter_ptr,
    .is_const = false
  });

  // Create basic blocks
  const cond_bb = llvm.LLVMAppendBasicBlockInContext(
    self.context, self.main_fn, "loop.cond"
  );
  const body_bb = llvm.LLVMAppendBasicBlockInContext(
    self.context, self.main_fn, "loop.body"
  );
  const after_bb = llvm.LLVMAppendBasicBlockInContext(
    self.context, self.main_fn, "loop.end"
  );

  // Jump to condition block
  _ = llvm.LLVMBuildBr(self.builder, cond_bb);

  // Condition block: check if i < end
  llvm.LLVMPositionBuilderAtEnd(self.builder, cond_bb);
  const current_val = llvm.LLVMBuildLoad2(self.builder, i64_type, iter_ptr, "i");
  const cond = llvm.LLVMBuildICmp(
    self.builder, llvm.LLVMIntSLT, current_val, llvm_end, "cond"
  );
  _ = llvm.LLVMBuildCondBr(self.builder, cond, body_bb, after_bb);

  // Body block: execute statements
  llvm.LLVMPositionBuilderAtEnd(self.builder, body_bb);
  while (true) {
    const token = lexer.next();
    if (token.tag == .rbrace) break;
    if (token.tag == .eof) {
      std.debug.print("Error: Unexpected EOF in loop body\n", .{});
      return error.UnexpectedEOF;
    }
    try compileStatement(self, lexer, token);
  }

  // Increment and loop back
  const next_val = llvm.LLVMBuildAdd(
    self.builder, current_val, llvm.LLVMConstInt(i64_type, 1, 0), "inc"
  );
  _ = llvm.LLVMBuildStore(self.builder, next_val, iter_ptr);
  _ = llvm.LLVMBuildBr(self.builder, cond_bb);

  // After block: continue after loop
  llvm.LLVMPositionBuilderAtEnd(self.builder, after_bb);
}
