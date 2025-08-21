const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const upgrade = lib.upgrade;

const Document2 = @import("../versions/2.zig").Document2;
const Document3 = @import("../versions/3.zig").Document3;

pub const DocumentPrev = Document2;
pub const DocumentNext = Document3;

pub fn upgrader(
    allocator: Allocator,
    prev: DocumentPrev,
    container: upgrade.Container,
) DocumentNext {
    var next = upgrade.upgradeValue(DocumentNext, allocator, prev, container);
    next.version = 3;
    return next;
}
