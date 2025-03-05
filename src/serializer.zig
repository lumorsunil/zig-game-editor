const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Serializer = struct {
    pub fn serializeIntermediate(value: anytype) @TypeOf(value).Serialized {
        const SerializedType = @TypeOf(value).Serialized;
        return SerializedType.init(value);
    }

    pub fn serialize(value: anytype, writer: anytype) !void {
        const serializedValue = serializeIntermediate(value);
        try std.json.stringify(serializedValue, .{}, writer);
    }

    pub fn deserialize(comptime T: type, allocator: Allocator, reader: anytype) !T {
        const deserializedValue = try std.json.parseFromTokenSource(T.Serialized, allocator, reader, .{});
        defer deserializedValue.deinit();
        return deserializedValue.value.deserialize(allocator);
    }

    pub fn MakeSerialize(
        comptime T: type,
        comptime SerializedFields: type,
        comptime initSerialized: fn (value: T) SerializedFields,
        comptime initDeserialized: fn (serialized: SerializedFields, allocator: Allocator) T,
    ) type {
        return struct {
            pub const Serialized = struct {
                fields: SerializedFields,

                pub fn init(value: T) Serialized {
                    return Serialized{
                        .value = initSerialized(value),
                    };
                }

                pub fn deserialize(self: Serialized, allocator: Allocator) T {
                    return initDeserialized(self.fields, allocator);
                }
            };
        };
    }
};
