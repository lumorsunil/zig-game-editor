const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const upgrade = lib.upgrade;

const V0 = @import("../versions/0.zig").ProjectOptions0;
const V1 = @import("../versions/1.zig").ProjectOptions1;

pub const DocumentPrev = V0;
pub const DocumentNext = V1;

pub fn upgrader(
    allocator: Allocator,
    prev: DocumentPrev,
    comptime container: upgrade.Container,
) DocumentNext {
    return upgrade.upgradeValue(DocumentNext, allocator, prev, container);
}
