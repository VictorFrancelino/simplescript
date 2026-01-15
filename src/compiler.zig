const std = @import("std");
const parser = @import("parser.zig");
const llvm_bindings = @import("llvm_bindings.zig");

const Lexer = parser.Lexer;
const Token = parser.Token;
const llvm = llvm_bindings.c;

pub const DiagnosticLevel = enum {
  note,
  warning,
  err,
  fatal,
};

pub const ErrorCode = enum {
  SyntaxError,
  TypeError,
  NameError,
  LinkerError,
  InternalError,
};

pub const DataType = enum {
  int,
  float,
  str,
  bool
};

pub const Variable = struct {
  llvm_value: llvm.LLVMValueRef,
  is_const: bool,
  data_type: DataType,
};

pub const Compiler = struct {
  allocator: std.mem.Allocator,
  locals: std.StringHashMap(Variable),
  scope_level: u32 = 0,

  context: llvm.LLVMContextRef,
  module: llvm.LLVMModuleRef,
  builder: llvm.LLVMBuilderRef,

  main_fn: llvm.LLVMValueRef,
  printf_fn: llvm.LLVMValueRef,
  printf_type: llvm.LLVMTypeRef,

  pub fn init(allocator: std.mem.Allocator, module_name: [*:0]const u8) !Compiler {
    // Create LLVM context
    const context = llvm.LLVMContextCreate() orelse {
      return error.LLVMContextCreationFailed;
    };

    // Create module
    const module = llvm.LLVMModuleCreateWithNameInContext(module_name, context) orelse {
      llvm.LLVMContextDispose(context);
      return error.LLVMModuleCreationFailed;
    };

    // Create IR builder
    const builder = llvm.LLVMCreateBuilderInContext(context) orelse {
      llvm.LLVMDisposeModule(module);
      llvm.LLVMContextDispose(context);
      return error.LLVMBuilderCreationFailed;
    };

    // Setup types
    const i32_type = llvm.LLVMInt32TypeInContext(context);
    const i8_type = llvm.LLVMInt8TypeInContext(context);
    const i8_ptr_type = llvm.LLVMPointerType(i8_type, 0);

    // Create printf function prototype
    var printf_args = [_]llvm.LLVMTypeRef{i8_ptr_type};
    const printf_type = llvm.LLVMFunctionType(
      i32_type,
      &printf_args,
      1,
      1 // varargs
    );
    const printf_fn = llvm.LLVMAddFunction(module, "printf", printf_type) orelse {
      llvm.LLVMDisposeBuilder(builder);
      llvm.LLVMDisposeModule(module);
      llvm.LLVMContextDispose(context);
      return error.LLVMPrintfCreationFailed;
    };

    // Create main function
    const main_fn_type = llvm.LLVMFunctionType(i32_type, null, 0, 0);
    const main_fn = llvm.LLVMAddFunction(module, "main", main_fn_type) orelse {
      llvm.LLVMDisposeBuilder(builder);
      llvm.LLVMDisposeModule(module);
      llvm.LLVMContextDispose(context);
      return error.LLVMMainCreationFailed;
    };

    // Create entry block for main
    const entry_block = llvm.LLVMAppendBasicBlockInContext(
      context, main_fn, "entry"
    );
    llvm.LLVMPositionBuilderAtEnd(builder, entry_block);

    return .{
      .allocator = allocator,
      .locals = std.StringHashMap(Variable).init(allocator),
      .context = context,
      .module = module,
      .builder = builder,
      .main_fn = main_fn,
      .printf_fn = printf_fn,
      .printf_type = printf_type,
    };
  }

  pub fn deinit(self: *Compiler) void {
    // Free all symbol table keys
    var iter = self.locals.keyIterator();
    while (iter.next()) |key_ptr| self.allocator.free(key_ptr.*);

    self.locals.deinit();
    llvm.LLVMDisposeBuilder(self.builder);
    llvm.LLVMDisposeModule(self.module);
    llvm.LLVMContextDispose(self.context);
  }

  pub fn finish(self: *Compiler) void {
    const i32_type = llvm.LLVMInt32TypeInContext(self.context);
    const zero = llvm.LLVMConstInt(i32_type, 0, 0);
    _ = llvm.LLVMBuildRet(self.builder, zero);
  }

  pub fn enterScope(self: *Compiler) void {
    self.scope_level += 1;
  }

  pub fn exitScope(self: *Compiler) void {
    self.scope_level -= 1;
  }

  pub fn printString(self: *Compiler, str_value: llvm.LLVMValueRef) !void {
    const fmt_str = llvm.LLVMBuildGlobalStringPtr(self.builder, "%s", "fmt.str");
    var args = [_]llvm.LLVMValueRef{ fmt_str, str_value };
    _ = llvm.LLVMBuildCall2(
      self.builder,
      self.printf_type,
      self.printf_fn,
      &args,
      args.len,
      ""
    );
  }

  pub fn printInt(self: *Compiler, value: llvm.LLVMValueRef) !void {
    const fmt_str = llvm.LLVMBuildGlobalStringPtr(self.builder, "%lld", "fmt.int");
    var args = [_]llvm.LLVMValueRef{ fmt_str, value };
    _ = llvm.LLVMBuildCall2(
      self.builder,
      self.printf_type,
      self.printf_fn,
      &args,
      args.len,
      ""
    );
  }

  pub fn printFloat(self: *Compiler, value: llvm.LLVMValueRef) !void {
    const fmt_str = llvm.LLVMBuildGlobalStringPtr(self.builder, "%f", "fmt.float");
    var args = [_]llvm.LLVMValueRef{ fmt_str, value };
    _ = llvm.LLVMBuildCall2(
      self.builder,
      self.printf_type,
      self.printf_fn,
      &args,
      args.len,
      ""
    );
  }

  pub fn printNewLine(self: *Compiler) !void {
    const fmt_str = llvm.LLVMBuildGlobalStringPtr(self.builder, "\n", "fmt.nl");
    var args = [_]llvm.LLVMValueRef{ fmt_str };
    _ = llvm.LLVMBuildCall2(self.builder, self.printf_type, self.printf_fn, &args, args.len, "");
  }

  pub fn printSpace(self: *Compiler) !void {
    const fmt_str = llvm.LLVMBuildGlobalStringPtr(self.builder, " ", "fmt.sp");
    var args = [_]llvm.LLVMValueRef{ fmt_str };
    _ = llvm.LLVMBuildCall2(self.builder, self.printf_type, self.printf_fn, &args, args.len, "");
  }

  pub fn report(
    self: *Compiler,
    level: DiagnosticLevel,
    code: ErrorCode,
    token: parser.Token,
    message: []const u8,
    extra: ?[]const u8,
  ) anyerror!void {
    _ = self;

    const color = switch (level) {
      .err, .fatal => "\x1b[31m",
      .warning => "\x1b[33m",
      .note => "\x1b[36m",
    };
    const reset = "\x1b[0m";

    std.debug.print("{s}[{s}]{s} at line {d}, col {d}: {s}\n", .{
      color,
      @tagName(code),
      reset,
      token.line,
      token.col,
      message,
    });

    if (extra) |e| std.debug.print("  └─ {s}Hint: {s}{s}\n", .{ "\x1b[32m", e, reset });

    if (level == .err or level == .fatal) {
      if (level == .fatal) std.process.exit(1);
      return error.CompileError;
    }

    return;
  }

  pub fn getLLVMType(self: *const Compiler, dtype: DataType) llvm.LLVMTypeRef {
    return switch (dtype) {
      .int => llvm.LLVMInt64TypeInContext(self.context),
      .float => llvm.LLVMDoubleTypeInContext(self.context),
      .bool => llvm.LLVMInt1TypeInContext(self.context),
      .str => llvm.LLVMPointerType(llvm.LLVMInt8TypeInContext(self.context), 0),
    };
  }

  pub inline fn getI64Type(self: *const Compiler) llvm.LLVMTypeRef {
    return llvm.LLVMInt64TypeInContext(self.context);
  }

  pub inline fn getI32Type(self: *const Compiler) llvm.LLVMTypeRef {
    return llvm.LLVMInt32TypeInContext(self.context);
  }

  pub inline fn getI8Type(self: *const Compiler) llvm.LLVMTypeRef {
    return llvm.LLVMInt8TypeInContext(self.context);
  }

  pub fn lookupVariable(self: *const Compiler, name: []const u8) ?Variable {
    return self.locals.get(name);
  }

  pub fn hasVariable(self: *const Compiler, name: []const u8) bool {
    return self.locals.contains(name);
  }
};
