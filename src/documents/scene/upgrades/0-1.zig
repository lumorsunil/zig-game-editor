const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const upgrade = lib.upgrade;

const Document0 = @import("../versions/0.zig").Document0;
const Document1 = @import("../versions/1.zig").Document1;

pub const DocumentPrev = Document0;
pub const DocumentNext = Document1;

pub fn upgrader(
    _: Allocator,
    prev: DocumentPrev,
    _: upgrade.Container,
) DocumentNext {
    return DocumentNext{
        .version = 1,
        .id = prev.id,
        .entities = prev.entities,
    };
}
