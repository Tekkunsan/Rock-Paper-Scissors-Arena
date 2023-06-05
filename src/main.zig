const std = @import("std");
const rand = std.rand;

const sokol = @import("sokol");
const slog = sokol.log;
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;
const stime = sokol.time;
const log = std.log;

const zstbi = @import("zstbi");
const zaudio = @import("zaudio");
const math = @import("math.zig");
const game = @import("states/game.zig");

const renderer = @import("renderer.zig");

pub const time = struct {
    pub var last: u64 = 0;
    pub var dt: f64 = 0;
};

pub const state = struct {
    pub var width: i32 = 1280;
    pub var height: i32 = 720;
    pub var audioEngine: *zaudio.Engine = undefined;
};

var gpAllocator: std.heap.GeneralPurposeAllocator(.{}) = undefined;

export fn init() void {
    gpAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpAllocator.allocator();

    renderer.init(allocator);
    renderer.setClearColor(255, 100, 255, 255);
    stime.setup();
    time.last = stime.now();

    zaudio.init(gpAllocator.allocator());

    state.audioEngine = zaudio.Engine.create(null) catch unreachable;

    game.init(allocator) catch |e| {
        log.err("Failed to initialize game: {}", .{e});
    };
}

export fn frame() void {
    time.dt = stime.sec(stime.laptime(&time.last)) * 10; // I also don't know what I'm doing
    game.update() catch |e| {
        log.info("Failed: {}", .{e});
    };

    renderer.begin();

    game.draw();

    renderer.end(sapp.widthf(), sapp.heightf());
    state.width = sapp.width();
    state.height = sapp.height();
}

export fn cleanup() void {
    game.deinit();
    state.audioEngine.destroy();
    zaudio.deinit();
    renderer.deinit();
    defer switch (gpAllocator.deinit()) {
        .ok => {
            std.log.info("Successfully Not Leak Memory LMAO", .{});
        },
        .leak => {
            std.log.info("Leak", .{});
        },
    };
}

pub fn main() !void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = state.width,
        .height = state.height,
        .icon = .{
            .sokol_default = true,
        },
        .window_title = "Ligmab",
        .logger = .{
            .func = slog.func,
        },
        .win32_console_attach = true,
    });
}

export fn emsc_main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .width = state.width,
        .height = state.height,
        .window_title = "Ligma",
        .logger = .{
            .func = slog.func,
        },
    });
}
