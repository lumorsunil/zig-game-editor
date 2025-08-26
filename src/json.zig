const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

pub const JsonArrayList = @import("json-array-list.zig").JsonArrayList;

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

    const items = @typeInfo(@FieldType(T, "items"));

    return switch (items) {
        .pointer => |p| if (p.size == .slice) p.child else null,
        else => null,
    };
}

fn isStruct(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => true,
        else => false,
    };
}

fn writeArrayList(arrayList: anytype, jw: anytype) !void {
    const Elem = std.meta.Elem(@TypeOf(arrayList.items));

    const writeFn = comptime brk: {
        if (isArrayList(Elem)) {
            break :brk writeArrayList;
        } else {
            break :brk writeValueRaw;
        }
    };

    try jw.beginArray();
    for (arrayList.items) |item| {
        try writeFn(item, jw);
    }
    try jw.endArray();
}

fn writeValueRaw(value: anytype, jw: anytype) !void {
    try jw.write(value);
}

pub fn writeObject(object: anytype, jw: anytype) !void {
    const ObjectType = @TypeOf(object);

    if (@typeInfo(ObjectType) == .pointer) return writeObject(object.*, jw);

    const fields = std.meta.fields(ObjectType);
    try jw.beginObject();
    inline for (fields) |field| {
        try jw.objectField(field.name);
        try writeValue(@field(object, field.name), jw);
    }
    try jw.endObject();
}

pub fn reportJsonErrorToWriter(reader: anytype, err: anyerror, writer: anytype) !void {
    const input = reader.scanner.input;
    const cursor = reader.scanner.cursor;

    try writer.print("Error parsing json at {}: {}", .{ cursor, err });
    const line, const startIdx = getReportSlice(input, cursor, 40);
    try writer.print("Input: {s}", .{line});
    for (0..cursor - startIdx + "error: Input: ".len) |_| {
        try writer.writeAll(" ");
    }
    try writer.writeAll("^\n");
}

pub fn reportJsonError(reader: anytype, err: anyerror) void {
    var stdoutBuffer: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&stdoutBuffer);

    const input = reader.scanner.input;
    const cursor = reader.scanner.cursor;

    std.log.err("Error parsing json at {}: {}", .{ cursor, err });
    const line, const startIdx = getReportSlice(input, cursor, 40);
    std.log.err("Input: {s}", .{line});
    for (0..cursor - startIdx + "error: Input: ".len) |_| {
        stdout.interface.writeAll(" ") catch unreachable;
    }
    stdout.interface.writeAll("^\n") catch unreachable;
}

fn getReportSlice(
    slice: []const u8,
    offset: usize,
    padding: usize,
) struct { []const u8, usize } {
    const endOfLineIdx = std.mem.indexOfScalarPos(u8, slice, offset, '\n') orelse slice.len;
    const startOfLineIdx = for (0..offset) |i| {
        if (slice[offset - i - 1] == '\n') break (offset - i - 1) + 1;
    } else 0;

    const endOfPaddingIdx = @min(slice.len, offset + padding);
    const startOfPaddingIdx = if (padding > offset) 0 else offset - padding;

    const startOfSlice = @max(startOfLineIdx, startOfPaddingIdx);
    const endOfSlice = @min(endOfLineIdx, endOfPaddingIdx);

    return .{ slice[startOfSlice..endOfSlice], startOfSlice };
}

pub fn parseFromSliceWithErrorReporting(
    comptime T: type,
    allocator: Allocator,
    buffer: []const u8,
    parseOptions: std.json.ParseOptions,
) !std.json.Parsed(T) {
    var fileStream = std.io.fixedBufferStream(buffer);
    const fileReader = fileStream.reader();
    var reader = std.json.reader(allocator, fileReader);
    defer reader.deinit();

    return std.json.parseFromTokenSource(T, allocator, &reader, parseOptions) catch |err| {
        reportJsonError(reader, err);
        return err;
    };
}

pub fn parseFromSliceWithErrorReportingLeaky(
    comptime T: type,
    allocator: Allocator,
    buffer: []const u8,
    parseOptions: std.json.ParseOptions,
) !T {
    var fileReader = std.Io.Reader.fixed(buffer);
    var reader = std.json.Reader.init(allocator, &fileReader);
    defer reader.deinit();

    return std.json.parseFromTokenSourceLeaky(T, allocator, &reader, parseOptions) catch |err| {
        reportJsonError(reader, err);
        return err;
    };
}
