const std = @import("std");
const Allocator = std.mem.Allocator;

const DEFAULT_CAPACITY = 256;

pub const StringZ = struct {
    buffer: [:0]u8,

    const Self = @This();

    pub const empty = Self{
        .buffer = undefined,
    };

    pub fn init(allocator: Allocator, initialSlice: [:0]const u8) Self {
        var self = Self{
            .buffer = allocator.allocSentinel(u8, DEFAULT_CAPACITY, 0) catch unreachable,
        };

        self.set(initialSlice);

        return self;
    }

    pub fn initFmt(allocator: Allocator, comptime fmt: []const u8, args: anytype) Self {
        return initFmtCapacity(allocator, DEFAULT_CAPACITY, fmt, args);
    }

    pub fn initFmtCapacity(
        allocator: Allocator,
        capacity: usize,
        comptime fmt: []const u8,
        args: anytype,
    ) Self {
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
        ) catch {
            std.log.warn("StringZ maximum length exceeded in setFmt", .{});
        };
    }

    pub fn format(
        self: @This(),
        writer: anytype,
    ) !void {
        try writer.writeAll(self.slice());
    }

    const PathFormatter = struct {
        value: StringZ,

        pub fn format(
            self: @This(),
            writer: anytype,
        ) !void {
            const allocator = std.heap.page_allocator;
            const normalizePathZ = @import("path.zig").normalizePathZ;
            const normalized = normalizePathZ(allocator, self.value.slice()) catch unreachable;
            defer allocator.free(normalized);
            try writer.writeAll(normalized);
        }
    };

    pub fn fmtPath(self: @This()) PathFormatter {
        return .{ .value = self };
    }

    pub const Path = struct {
        path: [:0]const u8,

        pub fn deinit(self: Path) void {
            const allocator = std.heap.page_allocator;
            allocator.free(self.path);
        }
    };

    /// Caller needs to call deinit
    pub fn getPath(self: @This()) Path {
        const allocator = std.heap.page_allocator;
        return .{
            .path = @import("path.zig").normalizePathZ(allocator, self.slice()) catch unreachable,
        };
    }

    pub fn jsonStringify(self: *const Self, jw: anytype) !void {
        try jw.write(self.slice());
    }

    pub fn jsonParse(allocator: Allocator, source: anytype, options: std.json.ParseOptions) !Self {
        const string = try std.json.innerParse([:0]const u8, allocator, source, options);
        return Self.init(allocator, string);
    }
};
