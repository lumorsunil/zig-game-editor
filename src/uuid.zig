const std = @import("std");
const Allocator = std.mem.Allocator;
const uuid = @import("uuid");

// Make sure this type is safe to copy
pub const UUIDSerializable = struct {
    uuid: uuid.Uuid,

    pub const zero: UUIDSerializable = .{ .uuid = 0 };

    pub fn init() UUIDSerializable {
        return UUIDSerializable{
            .uuid = uuid.v4.new(),
        };
    }

    pub fn serialize(self: UUIDSerializable) uuid.urn.Urn {
        return uuid.urn.serialize(self.uuid);
    }

    pub fn serializeZ(self: UUIDSerializable) [37:0]u8 {
        var buf: [37:0]u8 = undefined;
        const s = uuid.urn.serialize(self.uuid);
        _ = std.fmt.bufPrintZ(&buf, "{s}", .{s}) catch unreachable;
        return buf;
    }

    pub fn deserialize(k: []const u8) !UUIDSerializable {
        return UUIDSerializable{
            .uuid = try uuid.urn.deserialize(k),
        };
    }

    pub fn format(
        self: UUIDSerializable,
        writer: anytype,
    ) !void {
        try writer.writeAll(&uuid.urn.serialize(self.uuid));
    }

    pub fn jsonStringify(self: *const UUIDSerializable, jw: anytype) !void {
        try jw.write(uuid.urn.serialize(self.uuid));
    }

    pub fn jsonParse(allocator: Allocator, source: anytype, options: std.json.ParseOptions) !UUIDSerializable {
        const string = try std.json.innerParse(uuid.urn.Urn, allocator, source, options);

        return UUIDSerializable{
            .uuid = uuid.urn.deserialize(&string) catch return std.json.ParseFromValueError.InvalidCharacter,
        };
    }
};
