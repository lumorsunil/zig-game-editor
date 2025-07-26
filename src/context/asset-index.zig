const std = @import("std");
const lib = @import("lib");
const Context = lib.Context;
const UUID = lib.UUIDSerializable;

// Returns true if successful
pub fn saveIndex(self: *Context) bool {
    const p = self.currentProject orelse return false;
    std.log.debug("Updating index", .{});
    p.saveIndex() catch |err| {
        std.log.err("Could not save asset index: {}", .{err});
        return false;
    };
    return true;
}

pub fn getSceneReferencingTilemap(self: *Context, tilemapId: UUID) ?UUID {
    const p = self.currentProject orelse return null;
    const sceneIds = p.assetIndex.getIdsByDocumentType(self.allocator, .scene);
    defer self.allocator.free(sceneIds);

    for (sceneIds) |sceneId| {
        const document = (self.requestDocumentTypeById(.scene, sceneId) catch continue) orelse continue;
        for (document.getEntities().items) |entity| {
            switch (entity.type) {
                .tilemap => |tilemap| {
                    if (tilemap.tilemapId) |id| if (id.uuid == tilemapId.uuid) return sceneId;
                },
                else => continue,
            }
        }
    }

    return null;
}
