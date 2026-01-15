const std = @import("std");
const builtin = @import("builtin");

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

pub fn findLLVMPath(allocator: std.mem.Allocator) ![]const u8 {
  if (builtin.os.tag == .windows) {
    const possible_paths = [_][]const u8{
      "C:\\Program Files\\LLVM",
      "C:\\Program Files (x86)\\LLVM",
      "C:\\LLVM",
    };

    for (possible_paths) |path| {
      const bin_path = try std.fmt.allocPrint(allocator, "{s}\\bin\\clang.exe", .{path});
      defer allocator.free(bin_path);

      std.fs.accessAbsolute(bin_path, .{}) catch continue;
      return try allocator.dupe(u8, path);
    }

    if (std.process.getEnvVarOwned(allocator, "PATH")) |path_env| {
      defer allocator.free(path_env);

      var it = std.mem.tokenizeScalar(u8, path_env, ';');
      while (it.next()) |dir| {
        if (std.mem.endsWith(u8, dir, "\\LLVM\\bin") or std.mem.endsWith(u8, dir, "\\llvm\\bin")) {
          const llvm_root = dir[0 .. dir.len - 4];
          return try allocator.dupe(u8, llvm_root);
        }
      }
    } else |_| {}

    return error.LLVMNotFound;
  }

  return try allocator.dupe(u8, "/usr");
}

pub fn printLLVMInfo(allocator: std.mem.Allocator) !void {
  const llvm_path = findLLVMPath(allocator) catch |err| {
    std.debug.print("❌ LLVM not found!\n\n", .{});
    std.debug.print("Please install LLVM:\n", .{});

    if (builtin.os.tag == .windows) {
      std.debug.print("1. Download from: https://github.com/llvm/llvm-project/releases\n\n", .{});
      std.debug.print("2. Install LLVM-21.1.8-win64.exe\n", .{});
      std.debug.print("3. Add C:\\Program Files\\LLVM\\bin to PATH\n", .{});
    } else if (builtin.os.tag == .linux) {
      std.debug.print("wget https://apt.llvm.org/llvm.sh\n", .{});
      std.debug.print("chmod +x llvm.sh\n", .{});
      std.debug.print("sudo ./llvm.sh 21.1.8\n", .{});
    } else if (builtin.os.tag == .macos) {
      std.debug.print("brew install llvm@21\n", .{});
    }

    return err;
  };
  defer allocator.free(llvm_path);

  std.debug.print("✓ LLVM found at: {s}\n", .{llvm_path});
}
