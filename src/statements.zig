const std = @import("std");
const compiler_mod = @import("compiler.zig");
const parser_mod = @import("parser.zig");
const expressions_mod = @import("expressions.zig");
const llvm_bindings = @import("llvm_bindings.zig");

const Compiler = compiler_mod.Compiler;
const DataType = compiler_mod.DataType;
const Lexer = parser_mod.Lexer;
const llvm = llvm_bindings.c;
const Token = parser_mod.Token;
const TokenType = parser_mod.TokenType;

// Compile entire source code
pub fn compile(self: *Compiler, source: []const u8) !void {
  var lexer = Lexer.init(source);

  while (true) {
    const token = lexer.next();
    if (token.tag == .eof) break;
    try compileStatement(self, &lexer, token);
  }
}

// Compile a single statement
pub fn compileStatement(self: *Compiler, lexer: *Lexer, token: Token) anyerror!void {
  switch (token.tag) {
    .kw_var => try compileDeclaration(self, lexer, false),
    .kw_const => try compileDeclaration(self, lexer, true),
    .kw_for => try compileForLoop(self, lexer),
    .kw_if => try compileIf(self, lexer),
    .identifier => {
      if (std.mem.eql(u8, token.slice, "say")) { try compileSay(self, lexer); }
      else try compileAssignment(self, lexer, token);
    },
    .rbrace => {}, // Valid but no-op (closing brace of block)
    else => return try self.report(
      .err,
      .SyntaxError,
      token,
      "Unexpected token",
      "Check for missing characters or semicolons."
    )
  }
}

fn compileDeclaration(self: *Compiler, lexer: *Lexer, is_const: bool) !void {
  const name_token = lexer.next();
  if (name_token.tag != .identifier) {
    return self.report(
      .err,
      .SyntaxError,
      name_token,
      "Invalid variable name",
      "Use letters and underscores."
    );
  }

  var declared_type: DataType = undefined;

  if (lexer.peek().tag == .colon) {
    _ = lexer.next();
    const type_token = lexer.next();

    declared_type = std.meta.stringToEnum(DataType, type_token.slice) orelse {
      return self.report(
        .err,
        .TypeError,
        type_token,
        "Unknown data type",
        "Valid types: int, float, str, bool."
      );
    };
  } else {
    const end_col = name_token.col + name_token.slice.len;

    try self.report(
      .err,
      .SyntaxError,
      .{
        .tag = name_token.tag,
        .slice = name_token.slice,
        .line = name_token.line,
        .col = end_col
      },
      "Missing type annotation (e.g., ': int')",
      "SimpleScript requires explicit types."
    );
  }

  const equals_token = lexer.next();
  if (equals_token.tag != .equals) {
    return self.report(
      .err,
      .SyntaxError,
      equals_token,
      "Expected '=' after type",
      "Every variable must be initialized with a value."
    );
  }

  const expr_result = try expressions_mod.parseExpression(self, lexer);
  if (declared_type != expr_result.dtype) {
    return self.report(
      .err,
      .TypeError,
      name_token,
      "Type mismatch in assignment",
      "The assigned value does not match the declared type."
    );
  }

  const llvm_type = self.getLLVMType(declared_type);
  const ptr = llvm.LLVMBuildAlloca(self.builder, llvm_type, name_token.slice.ptr);
  _ = llvm.LLVMBuildStore(self.builder, expr_result.val, ptr);

  if (self.locals.getEntry(name_token.slice)) |entry| {
    entry.value_ptr.* = .{ .llvm_value = ptr, .is_const = is_const, .data_type = declared_type };
  } else {
    const name_copy = try self.allocator.dupe(u8, name_token.slice);
    try self.locals.put(name_copy, .{ .llvm_value = ptr, .is_const = is_const, .data_type = declared_type });
  }
}

pub fn compileAssignment(self: *Compiler, lexer: *Lexer, first_name_token: Token) !void {
  var targets = std.ArrayListUnmanaged(Token){};
  defer targets.deinit(self.allocator);

  try targets.append(self.allocator, first_name_token);

  while (lexer.peek().tag == .comma) {
    _ = lexer.next();

    const next_var = lexer.next();
    if (next_var.tag != .identifier) return try self.report(
      .err,
      .SyntaxError,
      next_var,
      "Expected variable name after comma",
      null
    );

    try targets.append(self.allocator, next_var);
  }

  const equals = lexer.next();
  if (equals.tag != .equals) {
    return self.report(
      .err,
      .SyntaxError,
      equals,
      "Expected '=' for assignment",
      null
    );
  }

  var values = std.ArrayListUnmanaged(expressions_mod.ExprResult){};
  defer values.deinit(self.allocator);

  for (0..targets.items.len) |i| {
    const expr_res = try expressions_mod.parseExpression(self, lexer);
    try values.append(self.allocator, expr_res);

    if (i < targets.items.len - 1) {
      const comma = lexer.next();
      if (comma.tag != .comma) return try self.report(
        .err,
        .SyntaxError,
        comma,
        "Expected comma separating values",
        "The number of values must match the number of variables."
      );
    }
  }

  if (values.items.len != targets.items.len) return try self.report(
    .err,
    .SyntaxError,
    first_name_token,
    "Assignment imbalance",
    "You must provide the same number of values and variables."
  );

  for (targets.items, values.items) |target_token, val_result| {
    const local = self.lookupVariable(target_token.slice) orelse {
      return try self.report(.err, .NameError, target_token, "Undefined variable", null);
    };

    if (local.is_const) return try self.report(.err, .TypeError, target_token, "Cannot reassign a constant", null);

    if (local.data_type != val_result.dtype) {
      return try self.report(
        .err,
        .TypeError,
        target_token,
        "Incompatible type in swap",
        "Attempting to assign a value of a different type to the variable."
      );
    }

    _ = llvm.LLVMBuildStore(self.builder, val_result.val, local.llvm_value);
  }
}

// Compile say(arg1, arg2, ...) function call
pub fn compileSay(self: *Compiler, lexer: *Lexer) !void {
  const lparen = lexer.next();
  if (lparen.tag != .lparen) return self.report(.err, .SyntaxError, lparen, "Missing '('", null);

  var first = true;
  while (lexer.peek().tag != .rparen and lexer.peek().tag != .eof) {
    if (!first) {
      const comma = lexer.next();
      if (comma.tag != .comma) return self.report(.err, .SyntaxError, comma, "Expected ',' or ')'", null);

      try self.printSpace();
    }

    const next_token = lexer.peek();

    if (next_token.tag == .string) {
      const str_token = lexer.next();
      const str_z = try self.allocator.dupeZ(u8, str_token.slice);
      defer self.allocator.free(str_z);
      const str_val = llvm.LLVMBuildGlobalStringPtr(self.builder, str_z, "str");
      try self.printString(str_val);
    } else {
      const expr_res = try expressions_mod.parseExpression(self, lexer);
      switch (expr_res.dtype) {
        .int, .bool => try self.printInt(expr_res.val),
        .float => try self.printFloat(expr_res.val),
        .str => try self.printString(expr_res.val),
      }
    }

    first = false;

    if (lexer.peek().tag != .comma) break;
  }

  const rparen = lexer.next();
  if (rparen.tag != .rparen) return self.report(.err, .SyntaxError, rparen, "Missing closing ')'", null);

  try self.printNewLine();
}

// Compile for loop: for i in start...end { body }
fn compileForLoop(self: *Compiler, lexer: *Lexer) !void {
  const i64_type = llvm.LLVMInt64TypeInContext(self.context);

  // Get iterator variable name
  const name_token = lexer.next();
  if (name_token.tag != .identifier) return self.report(.err, .SyntaxError, name_token, "Loop requires a variable (e.g., 'for i...')", null);

  const in_token = lexer.next();
  if (in_token.tag != .kw_in) return self.report(.err, .SyntaxError, in_token, "Expected keyword 'in'", "Syntax: for variable in start..end");

  const start_res = try expressions_mod.parseExpression(self, lexer);

  const range_token = lexer.next();
  if (range_token.tag != .range) return self.report(.err, .SyntaxError, range_token, "Expected '..' to define range", null);

  const end_res = try expressions_mod.parseExpression(self, lexer);

  // Allocate loop variable and initialize
  const iter_ptr = llvm.LLVMBuildAlloca(self.builder, i64_type, name_token.slice.ptr);
  _ = llvm.LLVMBuildStore(self.builder, start_res.val, iter_ptr);

  // Store in symbol table
  if (self.locals.getEntry(name_token.slice)) |entry| {
    entry.value_ptr.* = .{ .llvm_value = iter_ptr, .is_const = false, .data_type = .int };
  } else {
    const name_copy = try self.allocator.dupe(u8, name_token.slice);
    try self.locals.put(name_copy, .{ .llvm_value = iter_ptr, .is_const = false, .data_type = .int });
  }

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

  _ = llvm.LLVMBuildBr(self.builder, cond_bb);
  llvm.LLVMPositionBuilderAtEnd(self.builder, cond_bb);

  const current_val = llvm.LLVMBuildLoad2(self.builder, i64_type, iter_ptr, "i");
  const cond = llvm.LLVMBuildICmp(self.builder, llvm.LLVMIntSLT, current_val, end_res.val, "cond");
  _ = llvm.LLVMBuildCondBr(self.builder, cond, body_bb, after_bb);

  llvm.LLVMPositionBuilderAtEnd(self.builder, body_bb);
  try parseBlock(self, lexer);

  const next_val = llvm.LLVMBuildAdd(self.builder, current_val, llvm.LLVMConstInt(i64_type, 1, 0), "inc");
  _ = llvm.LLVMBuildStore(self.builder, next_val, iter_ptr);
  _ = llvm.LLVMBuildBr(self.builder, cond_bb);
  llvm.LLVMPositionBuilderAtEnd(self.builder, after_bb);
}

fn compileIf(compiler: *Compiler, lexer: *Lexer) !void {
  const condition = try expressions_mod.parseExpression(compiler, lexer);
  if (condition.dtype != .bool) return error.TypeMismatch;

  const parent_func = compiler.main_fn;

  const then_block = llvm.LLVMAppendBasicBlockInContext(compiler.context, parent_func, "then");
  const else_block = llvm.LLVMAppendBasicBlockInContext(compiler.context, parent_func, "else");
  const merge_block = llvm.LLVMAppendBasicBlockInContext(compiler.context, parent_func, "ifcont");

  _ = llvm.LLVMBuildCondBr(compiler.builder, condition.val, then_block, else_block);

  llvm.LLVMPositionBuilderAtEnd(compiler.builder, then_block);
  try parseBlock(compiler, lexer);
  _ = llvm.LLVMBuildBr(compiler.builder, merge_block);

  llvm.LLVMPositionBuilderAtEnd(compiler.builder, else_block);

  const next_token = lexer.peek();
  if (next_token.tag == .kw_else) {
    _ = lexer.next();

    if (lexer.peek().tag == .kw_if) {
      _ = lexer.next();
      try compileIf(compiler, lexer);
    } else {
      try parseBlock(compiler, lexer);
    }
  }

  _ = llvm.LLVMBuildBr(compiler.builder, merge_block);
  llvm.LLVMPositionBuilderAtEnd(compiler.builder, merge_block);
}

fn parseBlock(self: *Compiler, lexer: *Lexer) !void {
  const lbrace = lexer.next();
  if (lbrace.tag != .lbrace) {
    return self.report(.err, .SyntaxError, lbrace, "Missing opening brace '{'", null);
  }

  self.enterScope();

  while (lexer.peek().tag != .rbrace and lexer.peek().tag != .eof) {
    const token = lexer.next();
    try compileStatement(self, lexer, token);
  }

  const rbrace = lexer.next();
  if (rbrace.tag != .rbrace) {
    return self.report(.err, .SyntaxError, rbrace, "Missing closing brace '}'", null);
  }

  self.exitScope();
}
