const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("root").lib;
const Context = lib.Context;
const Vector = lib.Vector;
const drawTilemap = lib.drawTilemap;
const Scene = @import("persistent-data.zig").Scene;
const NonPersistentData = @import("non-persistent-data.zig").SceneNonPersistentData;
const DocumentGeneric = lib.documents.DocumentGeneric;
const SceneEntity = @import("persistent-data.zig").SceneEntity;
const SceneEntityType = @import("persistent-data.zig").SceneEntityType;

const tileSize = Vector{ 16, 16 };

pub const SceneDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(Scene, NonPersistentData, .{});

    pub fn init(allocator: Allocator) SceneDocument {
        return SceneDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *SceneDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getTextureFromEntityType(self: *SceneDocument, entityType: SceneEntityType) *rl.Texture2D {
        return switch (entityType) {
            .klet => &self.document.nonPersistentData.kletTexture,
            .mossing => &self.document.nonPersistentData.mossingTexture,
            .stening => &self.document.nonPersistentData.steningTexture,
            .barlingSpawner => &self.document.nonPersistentData.barlingTexture,
            .player => &self.document.nonPersistentData.playerTexture,
            .npc => &self.document.nonPersistentData.npcTexture,
            .exit, .entrance, .tilemap => unreachable,
        };
    }

    pub fn getSourceRectFromEntityType(
        entityType: SceneEntityType,
    ) rl.Rectangle {
        return switch (entityType) {
            .klet => rl.Rectangle.init(0, 0, 32, 32),
            .mossing => rl.Rectangle.init(0, 0, 32, 32),
            .stening => rl.Rectangle.init(0, 0, 32, 32),
            .barlingSpawner => rl.Rectangle.init(0, 0, 32, 32),
            .player => rl.Rectangle.init(1 * 16, 6 * 32, 16, 32),
            .npc => rl.Rectangle.init(0, 0, 32, 32),
            .exit, .entrance, .tilemap => unreachable,
        };
    }

    pub fn getSizeFromEntityType(
        entityType: SceneEntityType,
    ) rl.Vector2 {
        return switch (entityType) {
            .klet => rl.Vector2.init(32, 32),
            .mossing => rl.Vector2.init(32, 32),
            .stening => rl.Vector2.init(32, 32),
            .barlingSpawner => rl.Vector2.init(32, 32),
            .player => rl.Vector2.init(16, 32),
            .npc => rl.Vector2.init(32, 32),
            .exit => rl.Vector2.init(16, 16),
            .entrance => rl.Vector2.init(16, 16),
            .tilemap => unreachable,
        };
    }

    pub fn drawEntity(self: *SceneDocument, context: *Context, entity: SceneEntity) void {
        const scale: f32 = @floatFromInt(context.scale);
        switch (entity.type) {
            .klet, .mossing, .stening, .barlingSpawner, .player, .npc => {
                const source = getSourceRectFromEntityType(entity.type);
                const texture = self.getTextureFromEntityType(entity.type);
                const position: @Vector(2, f32) = @floatFromInt(entity.position);
                const dest = rl.Rectangle.init(
                    position[0] * scale,
                    position[1] * scale,
                    source.width * scale,
                    source.height * scale,
                );
                const origin = rl.Vector2.init(source.width / 2 * scale, source.height / 2 * scale);

                rl.drawTexturePro(texture.*, source, dest, origin, 0, rl.Color.white);
            },
            .tilemap => |tilemap| {
                const tilemapFileName = tilemap.fileName orelse return;
                const tilemapDocument = &(context.requestDocument(tilemapFileName) orelse return).content.?.tilemap;
                const tilemapSizeHalf = tilemapDocument.getTilemap().grid.size * tileSize * context.scaleV / Vector{ 2, 2 };
                const position = entity.position - tilemapSizeHalf;
                drawTilemap(context, tilemapDocument, position, true);
            },
            inline .exit, .entrance => |e| {
                const sizeInt = tileSize * context.scaleV;
                const scaledSizeInt = sizeInt * @as(Vector, @intFromFloat(e.scale.?));
                const size: @Vector(2, f32) = @floatFromInt(scaledSizeInt);
                const position: @Vector(2, f32) = @floatFromInt(entity.position * context.scaleV - scaledSizeInt / Vector{ 2, 2 });

                const rec = rl.Rectangle.init(
                    position[0],
                    position[1],
                    size[0],
                    size[1],
                );

                const color = if (entity.type == .exit) rl.Color.white.alpha(0.5) else rl.Color.yellow.alpha(0.5);

                rl.drawRectanglePro(rec, rl.Vector2.zero(), 0, color);
            },
        }
    }

    pub fn getEntities(self: *SceneDocument) *ArrayList(*SceneEntity) {
        return &self.document.persistentData.entities;
    }

    pub fn getSelectedEntities(self: SceneDocument) *ArrayList(*SceneEntity) {
        return &self.document.nonPersistentData.selectedEntities;
    }

    pub fn selectEntity(self: *SceneDocument, entity: *SceneEntity, allocator: Allocator) void {
        self.getSelectedEntities().clearRetainingCapacity();
        self.getSelectedEntities().append(allocator, entity) catch unreachable;
    }

    pub fn deleteEntity(self: *SceneDocument, allocator: Allocator, entity: *SceneEntity) void {
        const entitiesIndex = std.mem.indexOfScalar(*SceneEntity, self.document.persistentData.entities.items, entity) orelse unreachable;
        _ = self.document.persistentData.entities.swapRemove(entitiesIndex);
        entity.deinit(allocator);
        allocator.destroy(entity);
        const selectedEntitiesIndex = std.mem.indexOfScalar(*SceneEntity, self.getSelectedEntities().items, entity) orelse unreachable;
        _ = self.getSelectedEntities().swapRemove(selectedEntitiesIndex);
    }

    pub fn getTilemapFileName(self: *SceneDocument) ?[]const u8 {
        for (self.document.persistentData.entities.items) |entity| {
            switch (entity.type) {
                .tilemap => |tilemap| return tilemap.fileName,
                else => continue,
            }
        }

        return null;
    }

    pub fn getDragPayload(self: *SceneDocument) *?SceneEntityType {
        return &self.document.nonPersistentData.dragPayload;
    }

    pub fn getIsDragging(self: *SceneDocument) bool {
        return self.document.nonPersistentData.isDragging;
    }

    pub fn setIsDragging(self: *SceneDocument, isDragging: bool) void {
        self.document.nonPersistentData.isDragging = isDragging;
    }

    pub fn getDragStartPoint(self: *SceneDocument) ?Vector {
        return self.document.nonPersistentData.dragStartPoint;
    }

    pub fn setDragStartPoint(self: *SceneDocument, dragStartPoint: ?Vector) void {
        self.document.nonPersistentData.dragStartPoint = dragStartPoint;
    }
};
