const std = @import("std");
const parser = @import("parser.zig");
const llvm_bindings = @import("llvm.zig");
const statements = @import("statements.zig");

const Lexer = parser.Lexer;
const Token = parser.Token;
const llvm = llvm_bindings.c;

pub const Local = struct {
  llvm_value: llvm.LLVMValueRef,
  is_const: bool,
};

pub const Compiler = struct {
  allocator: std.mem.Allocator,
  locals: std.StringHashMap(Local),

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
      .locals = std.StringHashMap(Local).init(allocator),
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
    var iterator = self.locals.keyIterator();
    while (iterator.next()) |key_ptr| self.allocator.free(key_ptr.*);
    self.locals.deinit();

    llvm.LLVMDisposeBuilder(self.builder);
    llvm.LLVMDisposeModule(self.module);
    llvm.LLVMContextDispose(self.context);
  }

  // Finalize main function with return 0
  pub fn finish(self: *Compiler) void {
    const i32_type = llvm.LLVMInt32TypeInContext(self.context);
    const zero = llvm.LLVMConstInt(i32_type, 0, 0);
    _ = llvm.LLVMBuildRet(self.builder, zero);
  }

  pub const compile = statements.compile;
  pub const compileStatement = statements.compileStatement;
  pub const compileSay = statements.compileSay;

  // Print an integer value to stdout
  pub fn printInt(self: *Compiler, value: llvm.LLVMValueRef) !void {
    // Create format string: "%lld\n"
    const fmt_str = llvm.LLVMBuildGlobalStringPtr(
      self.builder,
      "%lld\n",
      "fmt.int"
    );

    // Call printf(fmt_str, value)
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

  // Get the i64 type for this context
  pub inline fn getI64Type(self: *const Compiler) llvm.LLVMTypeRef {
    return llvm.LLVMInt64TypeInContext(self.context);
  }

  // Get the i32 type for this context
  pub inline fn getI32Type(self: *const Compiler) llvm.LLVMTypeRef {
    return llvm.LLVMInt32TypeInContext(self.context);
  }

  // Get the i8 type for this context
  pub inline fn getI8Type(self: *const Compiler) llvm.LLVMTypeRef {
    return llvm.LLVMInt8TypeInContext(self.context);
  }

  // Look up a variable by name
  pub fn lookupVariable(self: *const Compiler, name: []const u8) ?Local {
    return self.locals.get(name);
  }

  // Check if a variable exists
  pub fn hasVariable(self: *const Compiler, name: []const u8) bool {
    return self.locals.contains(name);
  }
};
