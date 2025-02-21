const std = @import("std");
const Allocator = std.mem.Allocator;
const uuid = @import("uuid");

// Make sure this type is safe to copy
pub const UUIDSerializable = struct {
    uuid: uuid.Uuid,

    pub fn init() UUIDSerializable {
        return UUIDSerializable{
            .uuid = uuid.v4.new(),
        };
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
