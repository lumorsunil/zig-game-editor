const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const upgrade = lib.upgrade;

const Document1 = @import("../versions/1.zig").Document1;
const Document2 = @import("../versions/2.zig").Document2;
const Animation2 = @import("../versions/2.zig").Animation2;

pub const DocumentPrev = Document1;
pub const DocumentNext = Document2;

pub fn upgrader(
    allocator: Allocator,
    prev: DocumentPrev,
    _: upgrade.Container,
) DocumentNext {
    const animations = allocator.alloc(Animation2, prev.animations.len) catch unreachable;
    defer allocator.free(prev.animations);

    for (0..animations.len) |i| {
        const preva = prev.animations[i];
        animations[i] = Animation2{
            .offset = .{ 0, 0 },
            .spacing = .{ 0, 0 },
            .gridSize = preva.gridSize,
            .frameDuration = preva.frameDuration,
            .frames = preva.frames,
            .name = preva.name,
        };
    }

    return DocumentNext{
        .version = 2,
        .id = prev.id,
        .textureId = prev.textureId,
        .animations = animations,
    };
}
