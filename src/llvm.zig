pub const c = @cImport({
  @cInclude("llvm-c/Core.h");
  @cInclude("llvm-c/Target.h");
  @cInclude("llvm-c/TargetMachine.h");
  @cInclude("llvm-c/Analysis.h");
  @cInclude("llvm-c/Transforms/PassBuilder.h");
});

// Verify LLVM version at compile time
pub fn verifyVersion() void {
  // This will cause a compile error if LLVM headers aren't found
  _ = c.LLVMContextCreate;
}

pub const Context = c.LLVMContextRef;
pub const Module = c.LLVMModuleRef;
pub const Builder = c.LLVMBuilderRef;
pub const Type = c.LLVMTypeRef;
pub const Value = c.LLVMValueRef;
pub const BasicBlock = c.LLVMBasicBlockRef;

// Common LLVM optimization levels
pub const OptLevel = enum(c_uint) {
  none = c.LLVMCodeGenLevelNone,
  less = c.LLVMCodeGenLevelLess,
  default = c.LLVMCodeGenLevelDefault,
  aggressive = c.LLVMCodeGenLevelAggressive,
};

// Common relocation models
pub const RelocMode = enum(c_uint) {
  default = c.LLVMRelocDefault,
  static = c.LLVMRelocStatic,
  pic = c.LLVMRelocPIC,
  dynamic_no_pic = c.LLVMRelocDynamicNoPic,
};
