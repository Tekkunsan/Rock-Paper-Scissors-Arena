const sokol = @import("sokol");
const stime = sokol.time;

const std = @import("std");
const rand = std.rand;

const math = @import("../math.zig");
const renderer = @import("../renderer.zig");

const main = @import("../main.zig");
const time = main.time;
const mainState = main.state;

const zaudio = @import("zaudio");

const state = struct {
    var allocator: std.mem.Allocator = undefined;
    var rnd: rand.DefaultPrng = undefined;
    var objects: ObjectArrayList = undefined;
    var winner: ?renderer.ObjectType = null;

    var sndRock: *zaudio.Sound = undefined;
    var sndPaper: *zaudio.Sound = undefined;
    var sndScissors: *zaudio.Sound = undefined;
};

pub fn init(allocator: std.mem.Allocator) !void {
    state.allocator = allocator;
    state.objects = ObjectArrayList.init(allocator);

    const seed = stime.now();
    state.rnd = rand.DefaultPrng.init(seed);

    try initObj(.Rock, 30);
    try initObj(.Paper, 30);
    try initObj(.Scissors, 30);

    state.sndRock = try mainState.audioEngine.createSoundFromFile("res/sfx/rock.wav", .{});
    state.sndPaper = try mainState.audioEngine.createSoundFromFile("res/sfx/paper.wav", .{});
    state.sndScissors = try mainState.audioEngine.createSoundFromFile("res/sfx/scissors.wav", .{});
}

fn initObj(objType: renderer.ObjectType, count: usize) !void {
    for (0..count) |_| {
        const x = @intToFloat(f32, state.rnd.random().intRangeAtMost(i32, 32, mainState.width - 32));
        const y = @intToFloat(f32, state.rnd.random().intRangeAtMost(i32, 32, mainState.height - 32));
        const getDir: f32 = if (state.rnd.random().boolean()) 1 else -1;
        const velX = getDir * 3;
        const velY = getDir * 3;
        try state.objects.append(.{
            .pos = math.vec2(x, y),
            .vel = math.vec2(velX, velY),
            .type = objType,
        });
    }
}

pub fn deinit() void {
    state.sndRock.destroy();
    state.sndPaper.destroy();
    state.sndScissors.destroy();
    state.objects.deinit();
}

// Very Sorry
pub fn update() !void {
    for (state.objects.items) |*object| {
        try object.update();
        for (state.objects.items) |*other| {
            if (object != other) {
                const result = object.intersects(other.*);
                if (result.result) {
                    if (result.direction & IntersectResult.Dir.Left != 0) {
                        object.vel[0] = -3;
                    } else if (result.direction & IntersectResult.Dir.Right != 0) {
                        object.vel[0] = 3;
                    }

                    if (result.direction & IntersectResult.Dir.Top != 0) {
                        object.vel[1] = -3;
                    } else if (result.direction & IntersectResult.Dir.Bottom != 0) {
                        object.vel[1] = 3;
                    }

                    switch (object.type) {
                        .Rock => {
                            switch (other.type) {
                                .Paper => {
                                    object.type = .Paper;
                                    try state.sndPaper.start();
                                },
                                .Scissors => {
                                    object.type = .Rock;
                                    try state.sndRock.start();
                                },
                                else => {},
                            }
                        },
                        .Paper => {
                            switch (other.type) {
                                .Rock => {
                                    object.type = .Paper;
                                    try state.sndPaper.start();
                                },
                                .Scissors => {
                                    object.type = .Scissors;
                                    try state.sndScissors.start();
                                },
                                else => {},
                            }
                        },
                        .Scissors => {
                            switch (other.type) {
                                .Rock => {
                                    object.type = .Rock;
                                    try state.sndRock.start();
                                },
                                .Paper => {
                                    object.type = .Scissors;
                                    try state.sndScissors.start();
                                },
                                else => {},
                            }
                        },
                    }
                }
            }
        }
    }

    // Check if there's only one type left
    var rockCount: u32 = 0;
    var paperCount: u32 = 0;
    var scissorsCount: u32 = 0;
    for (state.objects.items) |*object| {
        switch (object.type) {
            .Rock => rockCount += 1,
            .Paper => paperCount += 1,
            .Scissors => scissorsCount += 1,
        }
    }

    if (rockCount == 0 and paperCount == 0) {
        state.winner = .Scissors;
    } else if (rockCount == 0 and scissorsCount == 0) {
        state.winner = .Paper;
    } else if (paperCount == 0 and scissorsCount == 0) {
        state.winner = .Rock;
    }

    if (state.winner) |winner| {
        std.log.info("Winnder: {}", .{winner});
        state.objects.clearAndFree();
        try initObj(.Rock, 30);
        try initObj(.Paper, 30);
        try initObj(.Scissors, 30);
        state.winner = null;
    }
}

pub fn draw() void {
    for (state.objects.items) |*object| {
        renderer.draw(object.pos, math.vec2(32, 32), object.type);
    }
}

const ObjectArrayList = std.ArrayList(Object);
const ObjectID = usize;
const ObjectIDArrayList = std.ArrayList(ObjectID);

const Object = struct {
    pos: math.Vec2 = math.vec2(0, 0),
    vel: math.Vec2 = math.vec2(0, 0),
    type: renderer.ObjectType = .Rock,
    target: ?ObjectID = null,

    pub fn update(self: *Object) !void {
        const dtf32 = @floatCast(f32, time.dt);

        if (self.target) |target| {
            const obj: Object = state.objects.items[target];
            const obj_pos: math.Vec2 = obj.pos;
            var diff = obj_pos - self.pos;
            diff = math.vec2Norm(diff);
            self.vel = diff * math.vec2(3, 3);

            if (obj.type == self.type) self.target = null;
        } else {
            switch (self.type) {
                .Rock => {
                    self.target = followRandom(try objsFilterType(state.objects, .Scissors));
                },
                .Paper => {
                    self.target = followRandom(try objsFilterType(state.objects, .Rock));
                },
                .Scissors => {
                    self.target = followRandom(try objsFilterType(state.objects, .Paper));
                },
            }
        }

        self.pos += self.vel * math.vec2(dtf32, dtf32);

        if (self.pos[0] < 16 or self.pos[0] > @intToFloat(f32, mainState.width) - 16) {
            self.vel[0] *= -1;
        }
        if (self.pos[1] < 16 or self.pos[1] > @intToFloat(f32, mainState.height) - 16) {
            self.vel[1] *= -1;
        }
    }

    pub fn intersects(self: Object, other: Object) IntersectResult {
        const halfSize: f32 = 16;

        var result = IntersectResult{ .result = false, .direction = IntersectResult.Dir.None };

        const min = self.pos - math.vec2(halfSize, halfSize);
        const max = self.pos + math.vec2(halfSize, halfSize);
        const otherMin = other.pos - math.vec2(halfSize, halfSize);
        const otherMax = other.pos + math.vec2(halfSize, halfSize);

        if (min[0] <= otherMax[0] and max[0] >= otherMin[0] and min[1] <= otherMax[1] and max[1] >= otherMin[1]) {
            result.result = true;

            if (self.pos[0] < other.pos[0]) {
                result.direction |= IntersectResult.Dir.Left;
            } else if (self.pos[0] > other.pos[0]) {
                result.direction |= IntersectResult.Dir.Right;
            }

            if (self.pos[1] < other.pos[1]) {
                result.direction |= IntersectResult.Dir.Top;
            } else if (self.pos[1] > other.pos[1]) {
                result.direction |= IntersectResult.Dir.Bottom;
            }
        }

        return result;
    }

    fn followRandom(objsToChoose: ObjectIDArrayList) ?ObjectID {
        defer objsToChoose.deinit();
        var len = objsToChoose.items.len;
        if (len == 0) return null;
        return objsToChoose.items[state.rnd.random().intRangeAtMost(usize, 0, len - 1)];
    }

    fn objsFilterType(objects: ObjectArrayList, objType: renderer.ObjectType) !ObjectIDArrayList {
        var ids = ObjectIDArrayList.init(state.allocator);
        for (objects.items, 0..) |obj, i| {
            if (obj.type == objType) {
                try ids.append(i);
            }
        }

        return ids;
    }
};

const IntersectResult = struct {
    const Dir = struct {
        const None: u4 = 0b0000;
        const Left: u4 = 0b1000;
        const Right: u4 = 0b0100;
        const Top: u4 = 0b0010;
        const Bottom: u4 = 0b0001;
    };
    result: bool,
    direction: u4,
};
