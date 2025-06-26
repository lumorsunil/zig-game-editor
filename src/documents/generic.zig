const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const json = lib.json;

pub const DocumentGenericConfig = struct {};

pub fn DocumentGeneric(
    comptime PersistentData: type,
    comptime NonPersistentData: type,
    comptime config: DocumentGenericConfig,
) type {
    return struct {
        persistentData: *PersistentData,
        nonPersistentData: *NonPersistentData,

        const Self = @This();

        pub const _PersistentData = PersistentData;
        pub const _NonPersistentData = NonPersistentData;
        pub const _config = config;

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

        pub fn deserialize(allocator: Allocator, dir: std.fs.Dir, path: [:0]const u8) !Self {
            const file = dir.openFile(path, .{}) catch |err| {
                std.log.err("Could not open file {s}: {}", .{ path, err });
                return err;
            };
            defer file.close();
            const fileReader = file.reader();
            var reader = std.json.reader(allocator, fileReader);
            defer reader.deinit();

            const parsed = std.json.parseFromTokenSource(PersistentData, allocator, &reader, .{}) catch |err| {
                const padding = 50;
                const stdout = std.io.getStdOut();

                std.log.err("Error parsing json at {d}: {}", .{ reader.scanner.cursor, err });
                std.log.err("Input: {s}", .{reader.scanner.input[reader.scanner.cursor - padding .. reader.scanner.cursor + padding]});
                for (0..padding + "error: Input: ".len) |_| {
                    stdout.writeAll(" ") catch unreachable;
                }
                stdout.writeAll("^\n") catch unreachable;

                return err;
            };
            const persistentData = allocator.create(PersistentData) catch unreachable;
            persistentData.* = parsed.value.clone(allocator);
            parsed.deinit();

            var document = Self{
                .persistentData = persistentData,
                .nonPersistentData = initNonPersistentData(allocator),
            };
            document.load(path);

            return document;
        }

        pub fn load(self: Self, path: [:0]const u8) void {
            self.nonPersistentData.load(path, self.persistentData);
        }
    };
}
