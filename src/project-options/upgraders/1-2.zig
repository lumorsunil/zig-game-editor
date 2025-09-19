const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const upgrade = lib.upgrade;

const V1 = @import("../versions/1.zig").ProjectOptions1;
const V2 = @import("../versions/2.zig").ProjectOptions2;

pub const DocumentPrev = V1;
pub const DocumentNext = V2;

pub fn upgrader(
    allocator: Allocator,
    prev: DocumentPrev,
    comptime container: upgrade.Container,
) DocumentNext {
    return upgrade.upgradeValue(DocumentNext, allocator, prev, container);
}
