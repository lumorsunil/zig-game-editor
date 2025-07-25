const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
pub const lib = @import("lib.zig");
const Property = lib.Property;

test "this is a test" {
    const json =
        \\{"id":"04a869ec-1a1b-4866-9f90-887a66d76f27","property":{"boolean":{"value":false}}}
    ;

    const property = try std.json.parseFromSlice(Property, std.testing.allocator, json, .{});
    defer property.deinit();

    try expectEqual(property.value.property, .boolean);
    try expectEqual(property.value.property.boolean.value, false);
}
