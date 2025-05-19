const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn StringZ(comptime capacity: usize) type {
    return struct {
        slice: [:0]u8,
        buffer: [:0]u8,

        const Self = @This();

        pub fn init(allocator: Allocator, initialSlice: []const u8) Self {
            const buffer = allocator.allocSentinel(u8, capacity, 0) catch unreachable;
            const slice = std.fmt.bufPrintZ(buffer, "{s}", .{initialSlice}) catch unreachable;

            return Self{
                .slice = slice,
                .buffer = buffer,
            };
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.buffer);
        }

        pub fn set(self: *Self, newSlice: [:0]const u8) void {
            self.slice = std.fmt.bufPrintZ(
                self.buffer,
                "{s}",
                .{newSlice},
            ) catch unreachable;
        }

        pub fn jsonStringify(self: *const Self, jw: anytype) !void {
            try jw.write(self.slice);
        }

        pub fn jsonParse(allocator: Allocator, source: anytype, options: std.json.ParseOptions) !Self {
            const string = try std.json.innerParse([]const u8, allocator, source, options);
            return Self.init(allocator, string);
        }
    };
}
