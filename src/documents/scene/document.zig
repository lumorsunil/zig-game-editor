const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const rl = @import("raylib");
const lib = @import("lib");
const config = @import("lib").config;
const Context = lib.Context;
const Vector = lib.Vector;
const drawTilemap = lib.drawTilemap.drawTilemap;
const Scene = @import("persistent-data.zig").Scene;
const NonPersistentData = @import("non-persistent-data.zig").SceneNonPersistentData;
const SceneTool = @import("non-persistent-data.zig").SceneTool;
const DocumentGeneric = lib.documents.DocumentGeneric;
const SceneEntity = @import("persistent-data.zig").SceneEntity;
const SceneEntityType = @import("persistent-data.zig").SceneEntityType;
const DragState = @import("non-persistent-data.zig").DragState;
const DragEntityState = @import("non-persistent-data.zig").DragEntityState;
const DragAction = @import("non-persistent-data.zig").DragAction;
const UUID = lib.UUIDSerializable;

pub const SceneDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(
        Scene,
        NonPersistentData,
        .{},
    );

    pub const setEntityReferenceWindowHeight = NonPersistentData.setEntityReferenceWindowHeight;
    pub const setEntityReferenceWindowWidth = NonPersistentData.setEntityReferenceWindowHeight;

    pub fn init(allocator: Allocator) SceneDocument {
        return SceneDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *SceneDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: SceneDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getSizeFromEntityType(
        context: *Context,
        entityType: SceneEntityType,
    ) !?rl.Vector2 {
        const tileSize = context.getTileSize();
        return switch (entityType) {
            .exit => rl.Vector2.init(@floatFromInt(tileSize[0]), @floatFromInt(tileSize[1])),
            .entrance => rl.Vector2.init(@floatFromInt(tileSize[0]), @floatFromInt(tileSize[1])),
            .point => rl.Vector2.init(1, 1),
            .tilemap => unreachable,
            .custom => |c| {
                const document = try context.requestDocumentTypeById(.entityType, c.entityTypeId) orelse return null;
                const cellSize: @Vector(2, f32) = @floatFromInt(document.getCellSize().*);
                return rl.Vector2.init(cellSize[0], cellSize[1]);
            },
        };
    }

    pub fn drawEntity(self: *SceneDocument, context: *Context, entity: *SceneEntity) void {
        if (self.isEntityHidden(entity.id)) return;

        const scale: f32 = @floatFromInt(context.scale);
        const tileSize = context.getTileSize();
        switch (entity.type) {
            .custom => |c| {
                const entityType = context.requestDocumentTypeById(.entityType, c.entityTypeId) catch return orelse {
                    std.log.debug("entity {} not found while drawing", .{c});
                    return;
                };
                const scaleV = @Vector(2, f32){ scale, scale };
                const position: @Vector(2, f32) = @floatFromInt(entity.position);
                const gridPosition = entityType.getGridPosition().*;
                const cellSize = entityType.getCellSize().*;
                const rectPos: @Vector(2, f32) = @floatFromInt(gridPosition * cellSize);
                const rectSize: @Vector(2, f32) = @floatFromInt(cellSize);
                const source = rl.Rectangle.init(
                    rectPos[0],
                    rectPos[1],
                    rectSize[0],
                    rectSize[1],
                );
                const sourceSize: @Vector(2, f32) = .{ source.width, source.height };
                const destSize = sourceSize * scaleV * entity.scale;

                const scaledPosition = position * @Vector(2, f32){ scale, scale };

                const textureId = entityType.getTextureId().* orelse {
                    return context.drawDefaultTexture(scaledPosition, sourceSize * entity.scale);
                };
                const texture = (context.requestTextureById(textureId) catch null) orelse {
                    return context.drawDefaultTexture(scaledPosition, sourceSize * entity.scale);
                };

                const dest = rl.Rectangle.init(
                    scaledPosition[0],
                    scaledPosition[1],
                    destSize[0],
                    destSize[1],
                );
                const origin = rl.Vector2.init(destSize[0] / 2, destSize[1] / 2);

                rl.drawTexturePro(texture.*, source, dest, origin, 0, rl.Color.white);
            },
            .tilemap => |*tilemap| {
                const tilemapId = tilemap.tilemapId orelse return;
                const document = context.requestDocumentById(tilemapId) orelse {
                    tilemap.tilemapId = null;
                    return;
                };
                const tilemapDocument = &document.content.?.tilemap;
                const tilemapSizeHalf = tilemapDocument.getTilemap().grid.size * tileSize * context.scaleV / Vector{ 2, 2 };
                const position = entity.position - tilemapSizeHalf;
                drawTilemap(context, tilemapDocument, position, context.scale, true);
            },
            .point => |p| {
                const sizeInt = Vector{ 1, 1 } * context.scaleV;
                const size: @Vector(2, f32) = @floatFromInt(sizeInt);
                const position: @Vector(2, f32) = @floatFromInt(entity.position * context.scaleV - sizeInt / Vector{ 2, 2 });

                const rec = rl.Rectangle.init(
                    position[0],
                    position[1],
                    size[0],
                    size[1],
                );

                const textRec = p.getLabelRect(position);

                p.drawLabel(textRec);
                rl.drawRectanglePro(rec, rl.Vector2.zero(), 0, rl.Color.white.alpha(0.5));
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

    pub fn drawEntityEx(
        _: *SceneDocument,
        context: *Context,
        tag: std.meta.FieldEnum(SceneEntityType),
        position: Vector,
    ) void {
        const tileSize = context.getTileSize();
        switch (tag) {
            .custom, .tilemap, .point => {},
            inline .exit, .entrance => {
                const sizeInt = tileSize * context.scaleV;
                const size: @Vector(2, f32) = @floatFromInt(sizeInt);
                const fPosition: @Vector(2, f32) = @floatFromInt(position * context.scaleV - sizeInt / Vector{ 2, 2 });

                const rec = rl.Rectangle.init(
                    fPosition[0],
                    fPosition[1],
                    size[0],
                    size[1],
                );

                const color = if (tag == .exit) rl.Color.white.alpha(0.5) else rl.Color.yellow.alpha(0.5);

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

    pub fn addEntity(
        self: *SceneDocument,
        allocator: Allocator,
        position: Vector,
        entityType: SceneEntityType,
    ) *SceneEntity {
        const entity = allocator.create(SceneEntity) catch unreachable;
        entity.* = SceneEntity.init(position, entityType);
        self.getEntities().append(allocator, entity) catch unreachable;
        return entity;
    }

    pub fn selectEntity(self: *SceneDocument, entity: *SceneEntity, allocator: Allocator) void {
        self.deselectEntities();
        self.getSelectedEntities().append(allocator, entity) catch unreachable;
    }

    pub fn deselectEntities(self: *SceneDocument) void {
        self.getSelectedEntities().clearRetainingCapacity();
    }

    pub fn deleteEntity(self: *SceneDocument, allocator: Allocator, entity: *SceneEntity) void {
        const entitiesIndex = std.mem.indexOfScalar(*SceneEntity, self.document.persistentData.entities.items, entity) orelse unreachable;
        _ = self.document.persistentData.entities.swapRemove(entitiesIndex);
        entity.deinit(allocator);
        allocator.destroy(entity);
        const selectedEntitiesIndex = std.mem.indexOfScalar(*SceneEntity, self.getSelectedEntities().items, entity) orelse unreachable;
        _ = self.getSelectedEntities().swapRemove(selectedEntitiesIndex);
    }

    pub fn hideEntity(
        self: *SceneDocument,
        allocator: Allocator,
        entityId: UUID,
    ) void {
        const entry = self.document.nonPersistentData.hiddenEntities.map.getOrPut(
            allocator,
            entityId,
        ) catch unreachable;
        entry.value_ptr.* = true;
    }

    pub fn showEntity(
        self: *SceneDocument,
        allocator: Allocator,
        entityId: UUID,
    ) void {
        const entry = self.document.nonPersistentData.hiddenEntities.map.getOrPut(
            allocator,
            entityId,
        ) catch unreachable;
        entry.value_ptr.* = false;
    }

    pub fn isEntityHidden(self: SceneDocument, entityId: UUID) bool {
        return self.document.nonPersistentData.hiddenEntities.map.get(entityId) orelse return false;
    }

    pub fn getTilemapId(self: *SceneDocument) ?*?UUID {
        for (self.document.persistentData.entities.items) |entity| {
            switch (entity.type) {
                .tilemap => |*tilemap| return &tilemap.tilemapId,
                else => continue,
            }
        }

        return null;
    }

    pub fn setTilemapId(self: *SceneDocument, id: UUID) void {
        for (self.getEntities().items) |entity| {
            if (entity.type == .tilemap) {
                entity.type.tilemap.tilemapId = id;
                break;
            }
        }
    }

    pub fn getDragPayload(self: *SceneDocument) ?SceneEntityType {
        const dragState = self.getDragState() orelse return null;
        return switch (dragState) {
            .payload => |payload| payload,
            .entityTarget => null,
        };
    }

    pub fn setDragPayload(self: *SceneDocument, payload: ?SceneEntityType) void {
        if (payload) |p| {
            self.setDragState(.{
                .payload = p,
            });
        } else {
            self.setDragState(null);
        }
    }

    pub fn getIsDragging(self: *SceneDocument) bool {
        return self.document.nonPersistentData.isDragging;
    }

    pub fn setIsDragging(self: *SceneDocument, isDragging: bool) void {
        self.document.nonPersistentData.isDragging = isDragging;
    }

    pub fn getDragState(self: *SceneDocument) ?DragState {
        return self.document.nonPersistentData.dragState;
    }

    pub fn setDragState(self: *SceneDocument, dragState: ?DragState) void {
        self.document.nonPersistentData.dragState = dragState;
    }

    pub fn getDragEntityState(self: *SceneDocument) ?DragEntityState {
        const dragState = self.getDragState() orelse return null;
        return switch (dragState) {
            .entityTarget => |entity| entity,
            .payload => null,
        };
    }

    pub fn setDragEntityState(self: *SceneDocument, state: ?DragEntityState) void {
        const dragEntityState = state orelse {
            self.setDragState(null);
            return;
        };
        self.setDragState(.{ .entityTarget = dragEntityState });
    }

    pub fn getDragAction(self: *SceneDocument) ?DragAction {
        return self.document.nonPersistentData.dragAction;
    }

    pub fn setDragAction(self: *SceneDocument, action: ?DragAction) void {
        self.document.nonPersistentData.dragAction = action;
    }

    pub fn openSetEntityWindow(
        self: *SceneDocument,
        targetSceneId: *?UUID,
        targetEntityId: *?UUID,
    ) void {
        self.document.nonPersistentData.setEntityWindow.isOpen = true;
        self.document.nonPersistentData.setEntityWindow.sceneTarget = targetSceneId;
        self.document.nonPersistentData.setEntityWindow.entityTarget = targetEntityId;
    }

    pub fn closeSetEntityWindow(self: *SceneDocument) void {
        self.document.nonPersistentData.setEntityWindow.isOpen = false;
    }

    pub fn isSetEntityWindowOpen(self: *SceneDocument) bool {
        return self.document.nonPersistentData.setEntityWindow.isOpen;
    }

    pub fn getSetEntityReferenceScene(self: *SceneDocument) ?UUID {
        return self.document.nonPersistentData.setEntityWindow.selectedScene;
    }

    pub fn getSetEntityReferenceEntity(self: *SceneDocument) ?UUID {
        return self.document.nonPersistentData.setEntityWindow.selectedEntity;
    }

    pub fn setSetEntityReferenceScene(self: *SceneDocument, sceneId: ?UUID) void {
        self.document.nonPersistentData.setEntityWindow.selectedScene = sceneId;
    }

    pub fn setSetEntityReferenceEntity(self: *SceneDocument, entityId: ?UUID) void {
        self.document.nonPersistentData.setEntityWindow.selectedEntity = entityId;
    }

    pub fn getSetEntityWindowRenderTexture(self: *SceneDocument) rl.RenderTexture {
        return self.document.nonPersistentData.setEntityWindow.renderTexture;
    }

    pub fn getSetEntityWindowCamera(self: *SceneDocument) *rl.Camera2D {
        return &self.document.nonPersistentData.setEntityWindow.camera;
    }

    pub fn commitSetEntityTarget(self: *SceneDocument) void {
        const sceneTarget = self.document.nonPersistentData.setEntityWindow.sceneTarget orelse return;
        const entityTarget = self.document.nonPersistentData.setEntityWindow.entityTarget orelse return;
        sceneTarget.* = self.getSetEntityReferenceScene() orelse unreachable;
        entityTarget.* = self.getSetEntityReferenceEntity() orelse unreachable;
    }

    pub fn clearSetEntityTarget(self: *SceneDocument) void {
        self.document.nonPersistentData.setEntityWindow.sceneTarget = null;
        self.document.nonPersistentData.setEntityWindow.entityTarget = null;
    }

    pub fn getEntityByInstanceId(self: *SceneDocument, id: UUID) ?*SceneEntity {
        for (self.getEntities().items) |entity| {
            if (entity.id.uuid == id.uuid) {
                return entity;
            }
        }

        return null;
    }

    pub fn getEntranceByKey(self: *SceneDocument, key: [:0]const u8) ?*SceneEntity {
        for (self.getEntities().items) |entity| {
            if (entity.type == .entrance and std.mem.eql(
                u8,
                entity.type.entrance.key.slice(),
                key,
            )) {
                return entity;
            }
        }

        return null;
    }

    pub fn setTool(self: *SceneDocument, newTool: SceneTool) void {
        self.deselectEntities();
        self.document.nonPersistentData.currentTool = newTool;
    }

    pub fn getTool(self: SceneDocument) SceneTool {
        return self.document.nonPersistentData.currentTool;
    }

    /// Caller owns result
    pub fn getReferencedEntities(
        self: *SceneDocument,
        allocator: Allocator,
        entity: *SceneEntity,
    ) []*SceneEntity {
        if (entity.type != .custom) return &.{};

        const references = entity.type.custom.properties.findEntityReferences(allocator);
        defer allocator.free(references);

        var list = ArrayList(*SceneEntity).empty;

        for (references) |reference| {
            const sceneId = reference.sceneId orelse continue;
            const entityId = reference.entityId orelse continue;
            if (sceneId.uuid != self.getId().uuid) continue;
            const sceneEntity = self.getEntityByInstanceId(entityId) orelse continue;

            list.append(allocator, sceneEntity) catch unreachable;
        }

        return list.toOwnedSlice(allocator) catch unreachable;
    }
};
