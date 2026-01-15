const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  const exe = b.addExecutable(.{
    .name = "simplescript",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/main.zig"),
      .target = target,
      .optimize = optimize,
    }),
  });

  if (target.result.os.tag == .windows) {
    const llvm_include_raw = std.process.getEnvVarOwned(b.allocator, "LLVM_INCLUDE_DIR") catch b.dupe("C:\\Program Files\\LLVM\\include");
    const llvm_lib_raw = std.process.getEnvVarOwned(b.allocator, "LLVM_LIB_DIR") catch b.dupe("C:\\Program Files\\LLVM\\lib");

    const llvm_include = std.mem.trim(u8, llvm_include_raw, " \n\r");
    const llvm_lib = std.mem.trim(u8, llvm_lib_raw, " \n\r");

    exe.addIncludePath(.{ .cwd_relative = llvm_include });
    exe.addLibraryPath(.{ .cwd_relative = llvm_lib });

    exe.linkSystemLibrary("LLVM-C");
    exe.linkSystemLibrary("ole32");
    exe.linkSystemLibrary("uuid");
    exe.linkSystemLibrary("advapi32");
    exe.linkSystemLibrary("shell32");
    exe.linkSystemLibrary("user32");
  } else {
    const llvm_config = "llvm-config-21";
    const include_path = b.run(&[_][]const u8{ llvm_config, "--includedir" });
    const lib_path = b.run(&[_][]const u8{ llvm_config, "--libdir" });

    exe.addIncludePath(.{ .cwd_relative = std.mem.trim(u8, include_path, " \n\r") });
    exe.addLibraryPath(.{ .cwd_relative = std.mem.trim(u8, lib_path, " \n\r") });

    exe.linkSystemLibrary("c++");
    exe.linkSystemLibrary("LLVM-21");

    if (target.result.os.tag == .linux) {
      exe.linkSystemLibrary("z");
      exe.linkSystemLibrary("zstd");
    }
  }

  exe.linkLibC();
  b.installArtifact(exe);

  const run_cmd = b.addRunArtifact(exe);
  run_cmd.step.dependOn(b.getInstallStep());
  if (b.args) |args| run_cmd.addArgs(args);

  const run_step = b.step("run", "Run the app");
  run_step.dependOn(&run_cmd.step);
}
