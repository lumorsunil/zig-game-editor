const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const lib = @import("root").lib;
const Vector = lib.Vector;
const StringZ = lib.StringZ;
const json = lib.json;

pub const Frame = struct {
    gridPos: Vector,
    origin: Vector,
    durationScale: f32,

    pub fn init(gridPos: Vector, origin: Vector) Frame {
        return Frame{
            .gridPos = gridPos,
            .origin = origin,
            .durationScale = 1,
        };
    }
};

pub const Animation = struct {
    name: StringZ(32),
    frames: ArrayList(Frame),
    gridSize: Vector,
    frameDuration: f32,

    pub fn init(allocator: Allocator, gridSize: Vector) Animation {
        return Animation{
            .name = StringZ(32).init(allocator, "New Animation"),
            .frames = ArrayList(Frame).initCapacity(allocator, 10) catch unreachable,
            .gridSize = gridSize,
            .frameDuration = 0.1,
        };
    }

    pub fn deinit(self: *Animation, allocator: Allocator) void {
        self.frames.deinit(allocator);
        self.name.deinit(allocator);
    }

    pub fn clone(self: Animation, allocator: Allocator) Animation {
        var cloned = Animation.init(allocator, self.gridSize);

        cloned.frames.appendSlice(allocator, self.frames.items) catch unreachable;
        cloned.name.set(self.name.slice);
        cloned.frameDuration = self.frameDuration;

        return cloned;
    }

    pub fn jsonStringify(self: *const @This(), jw: anytype) !void {
        try json.writeObject(self.*, jw);
    }

    pub fn jsonParse(
        allocator: Allocator,
        source: anytype,
        options: std.json.ParseOptions,
    ) !@This() {
        return try json.parseObject(@This(), allocator, source, options);
    }

    pub fn addFrame(self: *Animation, allocator: Allocator, gridPos: Vector) void {
        const origin: Vector = .{ 0, 0 };
        const frame = Frame.init(gridPos, origin);

        self.frames.append(allocator, frame) catch unreachable;
    }

    pub fn removeFrame(self: *Animation, index: usize) void {
        _ = self.frames.orderedRemove(index);
    }

    pub fn getTotalDuration(self: *Animation) f32 {
        var totalDuration: f32 = 0;

        for (self.frames.items) |frame| {
            totalDuration += frame.durationScale * self.frameDuration;
        }

        return totalDuration;
    }

    pub fn getFrameStart(self: Animation, frame: *Frame) f32 {
        var frameStartTime: f32 = 0;

        for (self.frames.items) |*f| {
            if (frame == f) break;
            frameStartTime += f.durationScale * self.frameDuration;
        }

        return frameStartTime;
    }
};
