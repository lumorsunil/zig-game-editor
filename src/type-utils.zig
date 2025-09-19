const std = @import("std");
const Type = std.builtin.Type;

pub fn ExtendFields(comptime T: type, comptime U: type) type {
    const extendFields = switch (@typeInfo(U)) {
        .@"struct" => |s| s.fields,
        inline else => |_, tt| @compileError("Type " ++ @typeName(U) ++ " has tag " ++ @tagName(tt) ++ " which is not supported."),
    };

    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            const filteredFields = filterOverridedFields(s.fields, extendFields);

            return @Type(.{ .@"struct" = .{
                .decls = &.{},
                .fields = comptimeConcat(Type.StructField, &.{
                    filteredFields,
                    extendFields,
                }),
                .is_tuple = s.is_tuple,
                .layout = s.layout,
            } });
        },
        inline else => |_, tt| @compileError("Type " ++ @typeName(T) ++ " has tag " ++ @tagName(tt) ++ " which is not supported."),
    }
}

fn filterOverridedFields(
    comptime baseFields: []const Type.StructField,
    comptime extendFields: []const Type.StructField,
) []const Type.StructField {
    var filteredFields: []const Type.StructField = &.{};

    for (baseFields) |baseField| {
        const overridden = for (extendFields) |extendField| {
            if (std.mem.eql(u8, baseField.name, extendField.name)) {
                break true;
            }
        } else false;

        if (!overridden) filteredFields = filteredFields ++ [_]Type.StructField{baseField};
    }

    return filteredFields;
}

pub fn comptimeConcat(comptime T: type, comptime concats: []const []const T) []const T {
    return comptime brk: {
        var result: []const T = &.{};

        for (concats) |c| {
            result = result ++ c;
        }

        break :brk result;
    };
}
