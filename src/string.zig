const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn StringZ(comptime capacity: usize) type {
    return struct {
        slice: [:0]u8,

        const Self = @This();

        pub fn init(allocator: Allocator, initialSlice: []const u8) Self {
            return Self{
                .slice = initSlice(allocator, initialSlice),
            };
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.getBuffer());
        }

        pub fn getBuffer(self: Self) [:0]u8 {
            return @ptrCast(self.slice.ptr[0..capacity]);
        }

        pub fn initSlice(allocator: Allocator, value: []const u8) [:0]u8 {
            const buffer = allocator.allocSentinel(u8, capacity, 0) catch unreachable;
            return std.fmt.bufPrintZ(buffer, "{s}", .{value}) catch unreachable;
        }

        pub fn set(self: *Self, newSlice: [:0]const u8) void {
            self.slice = std.fmt.bufPrintZ(
                self.getBuffer(),
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
