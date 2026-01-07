const std = @import("std");
const llvm_bindings = @import("llvm.zig");
const llvm = llvm_bindings.c;

// Initialize LLVM's native target for the current platform
// This must be called once before generating code
pub fn initNativeTarget() !void {
  // Initialize target
  if (llvm.LLVMInitializeNativeTarget() != 0) {
    std.debug.print("Error: Failed to initialize LLVM native target\n", .{});
    return error.LLVMTargetInitFailed;
  }

  // Initialize ASM printer (required for object file generation)
  if (llvm.LLVMInitializeNativeAsmPrinter() != 0) {
    std.debug.print("Error: Failed to initialize LLVM ASM printer\n", .{});
    return error.LLVMAsmPrinterInitFailed;
  }

  // Initialize ASM parser (required for inline assembly)
  if (llvm.LLVMInitializeNativeAsmParser() != 0) {
    std.debug.print("Error: Failed to initialize LLVM ASM parser\n", .{});
    return error.LLVMAsmParserInitFailed;
  }
}

// Optimization configuration
pub const OptimizationConfig = struct {
  // Optimization level: "default<O0>", "default<O1>", "default<O2>", "default<O3>"
  level: []const u8 = "default<O3>",

  // Code generation optimization level
  codegen_level: c_uint = llvm.LLVMCodeGenLevelAggressive,

  // Relocation model
  reloc_mode: c_uint = llvm.LLVMRelocPIC,

  // Code model
  code_model: c_uint = llvm.LLVMCodeModelDefault,

  // Target CPU (e.g., "generic", "native", "x86-64")
  cpu: [*:0]const u8 = "generic",

  // CPU features (e.g., "+avx2,+fma")
  features: [*:0]const u8 = "",
};

// Optimize and save LLVM module to object file
pub fn saveToBinary(module: llvm.LLVMModuleRef, filename: [*:0]const u8) !void {
  return saveToBinaryWithConfig(module, filename, .{});
}

// Optimize and save LLVM module with custom configuration
pub fn saveToBinaryWithConfig(
  module: llvm.LLVMModuleRef,
  filename: [*:0]const u8,
  config: OptimizationConfig,
) !void {
  // Get target triple for current platform
  const target_triple = llvm.LLVMGetDefaultTargetTriple();
  defer llvm.LLVMDisposeMessage(target_triple);

  // Get target from triple
  var target: llvm.LLVMTargetRef = undefined;
  var err_msg: [*c]u8 = undefined;

  if (llvm.LLVMGetTargetFromTriple(target_triple, &target, &err_msg) != 0) {
    defer llvm.LLVMDisposeMessage(err_msg);
    std.debug.print("Error: Failed to get target: {s}\n", .{err_msg});
    return error.LLVMTargetNotFound;
  }

  const target_machine = llvm.LLVMCreateTargetMachine(
    target,
    target_triple,
    config.cpu,
    config.features,
    config.codegen_level,
    config.reloc_mode,
    config.code_model,
  );
  defer llvm.LLVMDisposeTargetMachine(target_machine);

  if (target_machine == null) {
    std.debug.print("Error: Failed to create target machine\n", .{});
    return error.LLVMTargetMachineCreationFailed;
  }

  try runOptimizationPasses(module, target_machine, config.level);
  try verifyModule(module);
  try emitObjectFile(module, target_machine, filename);
}

fn runOptimizationPasses(
  module: llvm.LLVMModuleRef,
  target_machine: llvm.LLVMTargetMachineRef,
  passes: []const u8,
) !void {
  const options = llvm.LLVMCreatePassBuilderOptions();
  defer llvm.LLVMDisposePassBuilderOptions(options);

  if (options == null) {
    std.debug.print("Error: Failed to create pass builder options\n", .{});
    return error.LLVMPassBuilderCreationFailed;
  }

  // Run the optimization pipeline
  const result = llvm.LLVMRunPasses(
    module,
    passes.ptr,
    target_machine,
    options,
  );

  if (result != null) {
    defer llvm.LLVMDisposeErrorMessage(result);
    std.debug.print("Error: Optimization passes failed\n", .{});
    return error.LLVMOptimizationFailed;
  }
}

// Verify LLVM module is well-formed
fn verifyModule(module: llvm.LLVMModuleRef) !void {
  var err_msg: [*c]u8 = undefined;

  const result = llvm.LLVMVerifyModule(
    module,
    llvm.LLVMReturnStatusAction,
    &err_msg,
  );

  if (result != 0) {
    defer llvm.LLVMDisposeMessage(err_msg);
    std.debug.print("Error: Module verification failed:\n{s}\n", .{err_msg});
    return error.LLVMModuleVerificationFailed;
  }
}

fn emitObjectFile(
  module: llvm.LLVMModuleRef,
  target_machine: llvm.LLVMTargetMachineRef,
  filename: [*:0]const u8,
) !void {
  var err_msg: [*c]u8 = undefined;

  const result = llvm.LLVMTargetMachineEmitToFile(
    target_machine,
    module,
    filename,
    llvm.LLVMObjectFile,
    &err_msg,
  );

  if (result != 0) {
    defer llvm.LLVMDisposeMessage(err_msg);
    std.debug.print("Error: Failed to emit object file:\n{s}\n", .{err_msg});
    return error.LLVMEmitFailed;
  }
}

// Print LLVM module IR to stdout (useful for debugging)
pub fn printModuleIR(module: llvm.LLVMModuleRef) void {
  const ir = llvm.LLVMPrintModuleToString(module);
  defer llvm.LLVMDisposeMessage(ir);
  std.debug.print("{s}\n", .{ir});
}

pub fn dumpModuleIRToFile(module: llvm.LLVMModuleRef, filename: [*:0]const u8) !void {
  var err_msg: [*c]u8 = undefined;

  if (llvm.LLVMPrintModuleToFile(module, filename, &err_msg) != 0) {
    defer llvm.LLVMDisposeMessage(err_msg);
    std.debug.print("Error: Failed to dump IR to file:\n{s}\n", .{err_msg});
    return error.LLVMDumpFailed;
  }
}
