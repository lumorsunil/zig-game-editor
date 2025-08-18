const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const upgrade = lib.upgrade;

const Document1 = @import("../versions/1.zig").Document1;
const Document2 = @import("../versions/2.zig").Document2;
const Entity1 = @import("../versions/1.zig").Entity1;
const Entity2 = @import("../versions/2.zig").Entity2;

pub const DocumentPrev = Document1;
pub const DocumentNext = Document2;
const EntityNext = Entity2;
const EntityPrev = Entity1;

pub fn upgrader(
    allocator: Allocator,
    prev: DocumentPrev,
    _: upgrade.Container,
) DocumentNext {
    const entities = allocator.alloc(EntityNext, prev.entities.len) catch unreachable;
    defer allocator.free(prev.entities);
    for (0..prev.entities.len) |i| entities[i] = EntityNext{
        .id = prev.entities[i].id,
        .position = prev.entities[i].position,
        .scale = .{ 1, 1 },
        .type = prev.entities[i].type,
    };

    return DocumentNext{
        .version = 2,
        .id = prev.id,
        .entities = entities,
    };
}
