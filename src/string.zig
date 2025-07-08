const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn StringZ(comptime capacity: usize) type {
    return struct {
        buffer: [:0]u8,

        const Self = @This();

        pub const empty = Self{
            .buffer = undefined,
        };

        pub fn init(allocator: Allocator, initialSlice: [:0]const u8) Self {
            var self = Self{
                .buffer = allocator.allocSentinel(u8, capacity, 0) catch unreachable,
            };

            self.set(initialSlice);

            return self;
        }

        pub fn initFmt(allocator: Allocator, comptime fmt: []const u8, args: anytype) Self {
            var self = Self{
                .buffer = allocator.allocSentinel(u8, capacity, 0) catch unreachable,
            };

            self.setFmt(fmt, args);

            return self;
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.buffer);
        }

        pub fn clone(self: Self, allocator: Allocator) Self {
            return .init(allocator, self.slice());
        }

        pub fn slice(self: Self) [:0]const u8 {
            return std.mem.sliceTo(self.buffer, 0);
        }

        pub fn set(self: *Self, newSlice: [:0]const u8) void {
            const len = for (0..newSlice.len) |i| {
                if (newSlice[i] == 0) break i;
            } else newSlice.len;

            self.setFmt("{s}", .{newSlice[0..len]});
        }

        pub fn setFmt(self: *Self, comptime fmt: []const u8, args: anytype) void {
            _ = std.fmt.bufPrintZ(
                self.buffer,
                fmt,
                args,
            ) catch unreachable;
        }

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.writeAll(self.slice());
        }

        pub fn jsonStringify(self: *const Self, jw: anytype) !void {
            try jw.write(self.slice());
        }

        pub fn jsonParse(allocator: Allocator, source: anytype, options: std.json.ParseOptions) !Self {
            const string = try std.json.innerParse([:0]const u8, allocator, source, options);
            return Self.init(allocator, string);
        }
    };
}
