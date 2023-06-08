const std = @import("std");
const fs = std.fs;
const sokol = @import("deps/sokol-zig/build.zig");
const zstbi = @import("deps/zstbi/build.zig");
const zaudio = @import("deps/zaudio/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    if (target.getCpu().arch.isWasm()) {
        std.log.info("Building Wasm...", .{});
        buildWasm(b, target) catch |e| {
            std.log.err("Failed to Build Wasm: {}", .{e});
        };
    } else {
        std.log.info("Building Native...", .{});
        buildNative(b, target, optimize);
    }
}

pub fn buildNative(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) void {
    const exe = b.addExecutable(.{
        .name = "ProjectChuuni",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    _ = initModules(b, exe, target, optimize, false, null);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

pub fn buildWasm(b: *std.Build, target: std.zig.CrossTarget) !void {
    var wasm32TargetFreestanding = target;
    wasm32TargetFreestanding.os_tag = .freestanding;
    var wasm32TargetEmscripten = target;
    wasm32TargetEmscripten.os_tag = .emscripten;
    const optimize: std.builtin.Mode = .ReleaseSmall;

    const emcc_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "../../emcc" });
    defer b.allocator.free(emcc_path);
    const emrun_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "../../emrun" });
    defer b.allocator.free(emrun_path);

    const include_path = try fs.path.join(b.allocator, &.{ b.sysroot.?, "include" });
    defer b.allocator.free(include_path);

    // You need to build the game on freestanding, IDK why
    std.log.info("Build the game on {s}-{s} and {s}", .{
        @tagName(wasm32TargetFreestanding.getCpu().arch),
        @tagName(wasm32TargetFreestanding.os_tag.?),
        @tagName(optimize),
    });
    const libgame = b.addStaticLibrary(.{
        .name = "game",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = wasm32TargetFreestanding,
        .optimize = optimize,
    });

    // Build The dependencies using wasm32-emscripten
    std.log.info("Building Dependencies on Emscripten", .{});
    const modules = initModules(b, libgame, target, optimize, true, include_path);

    b.installArtifact(libgame);

    std.log.info("Link in emscripten Pls work...", .{});

    if (b.sysroot == null) {
        std.log.err("Please build with 'zig build -Dtarget=wasm32-emscripten --sysroot [path/to/emsdk]/upstream/emscripten/cache/sysroot'", .{});
        return error.SysRootExpected;
    }

    try fs.cwd().makePath("zig-out/web");

    const emcc = b.addSystemCommand(&.{
        emcc_path,
        "-Os",
        "--closure",
        "1",
        "src/emscripten/entry.c",
        "-ozig-out/web/index.html",
        "--shell-file",
        "src/emscripten/shell.html",
        "-Lzig-out/lib/",
        "-lgame",
        "-lsokol",
        "-lzstbi",
        "-lzaudio",
        "-sNO_FILESYSTEM=1",
        "-sMALLOC='emmalloc'",
        "-sASSERTIONS=0",
        "-sEXPORTED_FUNCTIONS=['_malloc','_free','_main']",
    });
    emcc.step.dependOn(&libgame.step);
    emcc.step.dependOn(&modules.sokol.step);
    emcc.step.dependOn(&modules.zstbi.step);
    emcc.step.dependOn(&modules.zaudio.step);
    emcc.step.dependOn(b.getInstallStep());

    const emrun = b.addSystemCommand(&.{ emrun_path, "zig-out/web/index.html" });
    emrun.step.dependOn(&emcc.step);
    b.step("run", "Run pacman").dependOn(&emrun.step);
}

const DependenciesLibs = struct {
    sokol: *std.Build.Step.Compile,
    zaudio: *std.Build.Step.Compile,
    zstbi: *std.Build.Step.Compile,
};

fn initModules(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.zig.CrossTarget,
    optimize: std.builtin.Mode,
    targetWasm: bool,
    includes: ?[]u8,
) DependenciesLibs {
    const sokolBuild = sokol.buildSokol(b, target, optimize, .{
        .backend = .gles2,
    }, "deps/sokol-zig/");
    const sokolModule = b.addModule("sokol", .{
        .source_file = std.Build.FileSource.relative("deps/sokol-zig/src/sokol/sokol.zig"),
    });

    exe.addModule("sokol", sokolModule);
    if (includes) |path| {
        sokolBuild.addIncludePath(path);
    }

    exe.linkLibrary(sokolBuild);

    const zstbiPkg = zstbi.package(b, target, optimize);
    if (includes) |path| {
        zstbiPkg.zstbi_c_cpp.addIncludePath(path);
    }
    zstbiPkg.link(exe);

    const zaudioPkg = zaudio.package(b, target, optimize);
    if (includes) |path| {
        zaudioPkg.zaudio_c_cpp.addIncludePath(path);
    }
    zaudioPkg.link(exe);

    // You need the libs to link for emscripten
    if (targetWasm) {
        b.installArtifact(sokolBuild);
        b.installArtifact(zstbiPkg.zstbi_c_cpp);
        b.installArtifact(zaudioPkg.zaudio_c_cpp);
    }

    return .{
        .sokol = sokolBuild,
        .zstbi = zstbiPkg.zstbi_c_cpp,
        .zaudio = zaudioPkg.zaudio_c_cpp,
    };
}
