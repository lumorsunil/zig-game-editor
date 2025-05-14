const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn DocumentGeneric(comptime PersistentData: type, comptime NonPersistentData: type) type {
    return struct {
        persistentData: *PersistentData,
        nonPersistentData: *NonPersistentData,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return Self{
                .persistentData = initPersistentData(allocator),
                .nonPersistentData = initNonPersistentData(allocator),
            };
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            self.persistentData.deinit(allocator);
            allocator.destroy(self.persistentData);
            self.nonPersistentData.deinit(allocator);
            allocator.destroy(self.nonPersistentData);
        }

        fn initPersistentData(allocator: Allocator) *PersistentData {
            const persistentData = allocator.create(PersistentData) catch unreachable;
            persistentData.* = PersistentData.init(allocator);
            return persistentData;
        }

        fn initNonPersistentData(allocator: Allocator) *NonPersistentData {
            const nonPersistentData = allocator.create(NonPersistentData) catch unreachable;
            nonPersistentData.* = NonPersistentData.init(allocator);
            return nonPersistentData;
        }

        pub fn serialize(self: *const Self, writer: anytype) !void {
            try std.json.stringify(self.persistentData.*, .{}, writer);
        }

        pub fn deserialize(allocator: Allocator, path: [:0]const u8, reader: anytype) !Self {
            const parsed = try std.json.parseFromTokenSource(PersistentData, allocator, reader, .{});
            const persistentData = allocator.create(PersistentData) catch unreachable;
            persistentData.* = parsed.value.clone(allocator);
            parsed.deinit();

            const document = Self{
                .persistentData = persistentData,
                .nonPersistentData = initNonPersistentData(allocator),
            };
            document.nonPersistentData.load(path, persistentData);

            return document;
        }
    };
}
