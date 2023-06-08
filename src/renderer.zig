const std = @import("std");
const log = std.log;

const sokol = @import("sokol");
const sapp = sokol.app;
const sgapp = sokol.app_gfx_glue;
const slog = sokol.log;
const sg = sokol.gfx;

const zstbi = @import("zstbi");

const MAX_QUADS = 1000;
const MAX_VERTICES = MAX_QUADS * 4;
const MAX_INDICES = MAX_QUADS * 6;

const math = @import("math.zig");
const basic_shader = @import("shaders/basic_shader.zig");

const Vertex = struct {
    pos: [3]f32,
    color: [4]f32,
    texCoords: [2]f32,
};

const state = struct {
    var passAction: sg.PassAction = .{};
    var pipeline: sg.Pipeline = .{};
    var bind: sg.Bindings = .{};

    var vertices: [MAX_VERTICES]Vertex = .{undefined} ** MAX_VERTICES;
    var currentVertex: usize = 0;

    var indices: [MAX_INDICES]u32 = .{0} ** MAX_INDICES;

    var imgDimension: math.Vec2 = .{ 0.0, 0.0 };
};

pub const ObjectType = enum(u8) {
    Rock = 0,
    Paper = 1,
    Scissors = 2,
};

pub fn init(allocator: std.mem.Allocator) void {
    sg.setup(.{
        .context = sgapp.context(),
        .logger = .{ .func = slog.func },
    });
    zstbi.init(allocator);

    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .type = .VERTEXBUFFER,
        .usage = .STREAM,
        .size = MAX_VERTICES * @sizeOf(Vertex),
    });

    var offset: u32 = 0;
    var i: usize = 0;
    while (i < MAX_INDICES) {
        state.indices[i] = offset + 0;
        state.indices[i + 1] = offset + 1;
        state.indices[i + 2] = offset + 2;
        state.indices[i + 3] = offset + 2;
        state.indices[i + 4] = offset + 3;
        state.indices[i + 5] = offset + 0;

        offset += 4;
        i += 6;
    }

    state.bind.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(state.indices[0..]),
    });

    // TODO Temporary
    var img = zstbi.Image.loadFromFile("res/sheet.png", 4) catch unreachable;
    defer img.deinit();

    state.imgDimension[0] = @intToFloat(f32, img.width);
    state.imgDimension[1] = @intToFloat(f32, img.height);

    var img_desc: sg.ImageDesc = .{
        .width = @intCast(i32, img.width),
        .height = @intCast(i32, img.height),
    };
    img_desc.data.subimage[0][0] = sg.asRange(img.data[0..]);
    // END Temporary

    setClearColor(0, 0, 0, 0);
    // log.info("Backend: {}", .{sg.queryBackend()});

    state.bind.fs_images[basic_shader.SLOT_tex] = sg.makeImage(img_desc);
    const shader = sg.makeShader(basic_shader.basicShaderShaderDesc(sg.queryBackend()));

    var pipDesc = sg.PipelineDesc{
        .index_type = .UINT32,
        .shader = shader,
    };
    pipDesc.layout.attrs[basic_shader.ATTR_vs_aPos] = .{ .format = .FLOAT3, .buffer_index = 0 };
    pipDesc.layout.attrs[basic_shader.ATTR_vs_aColor] = .{ .format = .FLOAT4, .buffer_index = 0 };
    pipDesc.layout.attrs[basic_shader.ATTR_vs_aTexCoords] = .{ .format = .FLOAT2, .buffer_index = 0 };

    pipDesc.colors[0].blend = .{
        .enabled = true,
        .src_factor_rgb = .SRC_ALPHA,
        .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        .src_factor_alpha = .SRC_ALPHA,
        .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
        .op_rgb = .ADD,
        .op_alpha = .ADD,
    };
    pipDesc.colors[0].write_mask = .RGBA;
    state.pipeline = sg.makePipeline(pipDesc);

    state.passAction.depth = .{ .action = .CLEAR, .value = 1.0 };
    state.passAction.stencil = .{ .action = .CLEAR, .value = 0 };
}

pub fn begin() void {
    state.currentVertex = 0;
}

/// Game Specific
pub fn draw(position: math.Vec2, dimension: math.Vec2, objType: ObjectType) void {
    const color: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 };

    const texCoords = switch (objType) {
        .Rock => getTexCoords(state.imgDimension, math.vec2(0, 0), math.vec2(32, 32)),
        .Paper => getTexCoords(state.imgDimension, math.vec2(32, 0), math.vec2(32, 32)),
        .Scissors => getTexCoords(state.imgDimension, math.vec2(64, 0), math.vec2(32, 32)),
    };

    state.vertices[state.currentVertex] = .{
        .pos = math.vec3(position[0] - (0.5 * dimension[0]), position[1] + (0.5 * dimension[1]), 0.0),
        .color = color,
        .texCoords = texCoords[0],
    };
    state.currentVertex += 1;

    state.vertices[state.currentVertex] = .{
        .pos = math.vec3(position[0] - (0.5 * dimension[0]), position[1] - (0.5 * dimension[1]), 0.0),
        .color = color,
        .texCoords = texCoords[1],
    };
    state.currentVertex += 1;

    state.vertices[state.currentVertex] = .{
        .pos = math.vec3(position[0] + (0.5 * dimension[0]), position[1] - (0.5 * dimension[1]), 0.0),
        .color = color,
        .texCoords = texCoords[2],
    };
    state.currentVertex += 1;

    state.vertices[state.currentVertex] = .{
        .pos = math.vec3(position[0] + (0.5 * dimension[0]), position[1] + (0.5 * dimension[1]), 0.0),
        .color = color,
        .texCoords = texCoords[3],
    };
    state.currentVertex += 1;
}

pub fn end(width: f32, height: f32) void {
    sg.updateBuffer(state.bind.vertex_buffers[0], sg.asRange(state.vertices[0..state.currentVertex]));
    const numElements = @intCast(u32, (state.currentVertex / 4) * 6);

    const vs_params = basic_shader.VsParams{
        .mvp = math.mat4Ortho(0, width, 0, height, -5, 5),
    };

    sg.beginDefaultPass(state.passAction, sapp.width(), sapp.height());
    sg.applyPipeline(state.pipeline);
    sg.applyBindings(state.bind);
    sg.applyUniforms(.VS, basic_shader.SLOT_vs_params, sg.asRange(&vs_params));
    sg.draw(0, numElements, 1);
    sg.endPass();
    sg.commit();
}

pub fn deinit() void {
    sg.shutdown();
    zstbi.deinit();
}

pub fn setClearColor(_r: u8, _g: u8, _b: u8, _a: u8) void {
    const r = @intToFloat(f32, _r) / 255;
    const g = @intToFloat(f32, _g) / 255;
    const b = @intToFloat(f32, _b) / 255;
    const a = @intToFloat(f32, _a) / 255;

    state.passAction.colors[0] = .{
        .action = .CLEAR,
        .value = .{ .r = r, .g = g, .b = b, .a = a },
    };
}

fn getTexCoords(imageDimension: math.Vec2, position: math.Vec2, dimension: math.Vec2) [4]math.Vec2 {
    const x = position[0] / imageDimension[0];
    const y = position[1] / imageDimension[1];
    const w = dimension[0] / imageDimension[0];
    const h = dimension[1] / imageDimension[1];

    return .{
        math.vec2(x, y),
        math.vec2(x, y + h),
        math.vec2(x + w, y + h),
        math.vec2(x + w, y),
    };
}
