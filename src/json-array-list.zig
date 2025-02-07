const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const json = std.json;

pub fn JsonArrayList(comptime T: type) type {
    return struct {
        arrayList: ArrayListUnmanaged(T),

        pub fn init(allocator: Allocator, capacity: usize) JsonArrayList(T) {
            return JsonArrayList(T){
                .arrayList = ArrayListUnmanaged(T).initCapacity(allocator, capacity) catch unreachable,
            };
        }

        pub inline fn initWith(allocator: Allocator, data: T, length: usize) JsonArrayList(T) {
            var jal = JsonArrayList(T).init(allocator, length);

            jal.arrayList.appendNTimes(allocator, data, length) catch unreachable;

            std.log.debug("initWith length: {d}, jal len: {d}", .{ length, jal.slice().len });

            return jal;
        }

        pub fn slice(self: JsonArrayList(T)) []T {
            return self.arrayList.items;
        }

        pub fn copyFrom(allocator: Allocator, source: []const T) !JsonArrayList(T) {
            return JsonArrayList(T){
                .arrayList = std.ArrayListUnmanaged(T).fromOwnedSlice(try allocator.dupe(T, source)),
            };
        }

        pub fn jsonStringify(
            self: JsonArrayList(T),
            source: anytype,
        ) !void {
            try source.write(self.slice());
        }

        pub fn jsonParse(
            allocator: Allocator,
            source: anytype,
            options: json.ParseOptions,
        ) !JsonArrayList(T) {
            const items = try json.innerParse([]T, allocator, source, options);
            defer allocator.free(items);
            return try copyFrom(allocator, items);
        }

        pub fn deinit(self: *JsonArrayList(T), allocator: Allocator) void {
            self.arrayList.deinit(allocator);
        }
    };
}
