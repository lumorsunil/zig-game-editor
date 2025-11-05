const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const upgrade = lib.upgrade;

const Document1 = @import("../versions/1.zig").Document1;
const Document2 = @import("../versions/2.zig").Document2;

pub const DocumentPrev = Document1;
pub const DocumentNext = Document2;

pub fn upgrader(
    _: Allocator,
    prev: DocumentPrev,
    _: upgrade.Container,
) DocumentNext {
    return DocumentNext{
        .version = 2,
        .id = prev.id,
        .name = prev.name,
        .icon = prev.icon,
        .hitboxOrigin = .{ 0, 0 },
        .hitboxSize = prev.icon.cellSize,
        .properties = prev.properties,
    };
}
