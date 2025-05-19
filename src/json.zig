const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

pub const JsonArrayList = @import("json-array-list.zig").JsonArrayList;

// pub fn serialize(allocator: Allocator, value: anytype) SerializeWrapper(@TypeOf(value)) {
//     const T = @TypeOf(value);
//     const typeInfo = @typeInfo(T);
//     switch (typeInfo) {
//         .Struct => |s| {
//             if (isArrayList(T)) {
//                 const ChildType = SerializeWrapper(ElementOfArrayList(T).?);
//                 const slice = allocator.alloc(ChildType, value.items.len) catch unreachable;
//                 for (value.items, 0..) |item, i| {
//                     slice[i] = serialize(allocator, item);
//                 }
//                 return slice;
//             }
//
//             var object: T = undefined;
//
//             for (s.fields) |field| {
//                 @field(object, field.name) = serialize(allocator, @field(value, field.name));
//             }
//
//             return object;
//         },
//         .Union => {
//             const activeTag = std.meta.activeTag(value);
//
//             return @unionInit(
//                 SerializeWrapper(T),
//                 @tagName(activeTag),
//                 serialize(
//                     @field(value, @tagName(activeTag)),
//                 ),
//             );
//         },
//         inline .Array, .Pointer, .Optional, .Vector => |a| {
//             var wrapped = a;
//             wrapped.child = SerializeWrapper(wrapped.child);
//             return @Type(wrapped);
//         },
//         inline else => |e| return @Type(e),
//     }
// }
//
// pub fn SerializeWrapper(comptime T: type) type {
//     const typeInfo = @typeInfo(T);
//     switch (typeInfo) {
//         inline .Struct, .Union => |s, tag| {
//             var wrapped = s;
//
//             if (isArrayList(T)) {
//                 return []SerializeWrapper(ElementOfArrayList(T).?);
//             }
//
//             wrapped.fields = &.{};
//             wrapped.decls = &.{};
//
//             for (0..s.fields.len) |i| {
//                 const FieldType = SerializeWrapper(s.fields[i].type);
//                 var wrappedField = s.fields[i];
//                 wrappedField.type = FieldType;
//                 wrappedField.alignment = @alignOf(FieldType);
//                 wrapped.fields = wrapped.fields ++ [_]std.meta.Elem(@TypeOf(s.fields)){wrappedField};
//             }
//
//             return @Type(@unionInit(std.builtin.Type, @tagName(tag), wrapped));
//         },
//         inline .Pointer => |a, tag| {
//             var wrapped = a;
//             wrapped.child = SerializeWrapper(wrapped.child);
//             const WrappedTypeWithoutAlignment = @Type(@unionInit(std.builtin.Type, @tagName(tag), wrapped));
//             wrapped.alignment = @alignOf(WrappedTypeWithoutAlignment);
//             return @Type(@unionInit(std.builtin.Type, @tagName(tag), wrapped));
//         },
//         inline .Array, .Optional, .Vector => |a, tag| {
//             var wrapped = a;
//             wrapped.child = SerializeWrapper(wrapped.child);
//             return @Type(@unionInit(std.builtin.Type, @tagName(tag), wrapped));
//         },
//         inline else => return T,
//     }
// }

pub fn SerializeObjectShallow(comptime T: type) type {
    const typeInfo = @typeInfo(T);
    switch (typeInfo) {
        inline .Struct => |s, tag| {
            var wrapped = s;

            wrapped.fields = &.{};
            wrapped.decls = &.{};

            for (0..s.fields.len) |i| {
                const FieldType = s.fields[i].type;

                var wrappedField = s.fields[i];

                if (isArrayList(FieldType)) {
                    wrappedField.type = []ElementOfArrayList(FieldType).?;
                } else {
                    wrappedField.type = FieldType;
                }

                wrappedField.alignment = @alignOf(wrappedField.type);
                wrapped.fields = wrapped.fields ++ [_]std.meta.Elem(@TypeOf(s.fields)){wrappedField};
            }

            return @Type(@unionInit(std.builtin.Type, @tagName(tag), wrapped));
        },
        else => return T,
    }
}

fn writeValue(value: anytype, jw: anytype) !void {
    const writeFn = comptime brk: {
        const ValueType = @TypeOf(value);
        if (isArrayList(ValueType)) {
            break :brk writeArrayList;
        } else {
            break :brk writeValueRaw;
        }
    };

    try writeFn(value, jw);
}

fn isArrayList(comptime T: type) bool {
    if (!isStruct(T)) return false;
    if (!@hasField(T, "items")) return false;

    const ChildType = ElementOfArrayList(T).?;
    return std.ArrayList(ChildType) == T or std.ArrayListUnmanaged(ChildType) == T;
}

fn ElementOfArrayList(comptime T: type) ?type {
    if (!isStruct(T)) return null;
    if (!@hasField(T, "items")) return null;

    const items = @typeInfo(std.meta.FieldType(T, .items));

    return switch (items) {
        .Pointer => |p| if (p.size == .Slice) p.child else null,
        else => null,
    };
}

fn isStruct(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Struct => true,
        else => false,
    };
}

fn writeArrayList(arrayList: anytype, jw: anytype) !void {
    try jw.write(arrayList.items);
}

fn writeValueRaw(value: anytype, jw: anytype) !void {
    try jw.write(value);
}

pub fn writeObject(object: anytype, jw: anytype) !void {
    const ObjectType = @TypeOf(object);

    if (@typeInfo(ObjectType) == .Pointer) return writeObject(object.*, jw);

    const fields = std.meta.fields(ObjectType);
    try jw.beginObject();
    inline for (fields) |field| {
        try jw.objectField(field.name);
        try writeValue(@field(object, field.name), jw);
    }
    try jw.endObject();
}

pub fn parseObject(
    comptime T: type,
    allocator: Allocator,
    source: anytype,
    options: std.json.ParseOptions,
) !T {
    const serializedObject = try std.json.innerParse(
        SerializeObjectShallow(T),
        allocator,
        source,
        options,
    );
    var parsedObject: T = undefined;

    inline for (std.meta.fields(T)) |field| {
        const initFn = comptime brk: {
            if (isArrayList(field.type)) {
                break :brk initArrayList;
            } else {
                break :brk initField;
            }
        };

        try initFn(T, allocator, serializedObject, &parsedObject, field);
    }

    return parsedObject;
}

fn initArrayList(
    comptime T: type,
    allocator: Allocator,
    serializedObject: SerializeObjectShallow(T),
    parsedObject: *T,
    comptime field: std.builtin.Type.StructField,
) !void {
    const serializedArray = @field(serializedObject, field.name);
    @field(parsedObject, field.name) = try ArrayList(ElementOfArrayList(field.type).?).initCapacity(allocator, serializedArray.len);

    for (0..serializedArray.len) |i| {
        @field(parsedObject, field.name).appendAssumeCapacity(serializedArray[i]);
    }
}

fn initField(
    comptime T: type,
    _: Allocator,
    serializedObject: SerializeObjectShallow(T),
    parsedObject: *T,
    comptime field: std.builtin.Type.StructField,
) !void {
    @field(parsedObject, field.name) = @field(serializedObject, field.name);
}
