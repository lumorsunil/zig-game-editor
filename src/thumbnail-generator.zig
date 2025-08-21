const rl = @import("raylib");
const lib = @import("lib");
const Context = lib.Context;
const Document = lib.Document;
const drawTilemap = lib.drawTilemap;

pub fn generateThumbnail(self: *Context, document: *Document) !?rl.Image {
    const content = &(document.content orelse return null);

    switch (content.*) {
        .texture => |texture| {
            return try rl.loadImageFromTexture(texture.getTexture().?.*);
        },
        .sound, .font => return null,
        .animation => |*animationDocument| {
            const animations = animationDocument.getAnimations();
            if (animations.items.len == 0) return null;
            const textureId = animationDocument.getTextureId().* orelse return null;
            const texture = (self.requestTextureById(textureId) catch return null) orelse return null;
            const animation = animations.items[0];
            if (animation.frames.items.len == 0) return null;
            const frame = animation.frames.items[0];
            const gridPosition = frame.gridPos;
            const sourceRectMin = @as(
                @Vector(2, f32),
                @floatFromInt(gridPosition * animation.gridSize),
            );
            const fCellSize: @Vector(2, f32) = @floatFromInt(animation.gridSize);
            const sourceRect = rl.Rectangle.init(
                sourceRectMin[0],
                sourceRectMin[1],
                fCellSize[0],
                fCellSize[1],
            );
            const dstRect = rl.Rectangle.init(0, 0, fCellSize[0], fCellSize[1]);
            var image = rl.genImageColor(animation.gridSize[0], animation.gridSize[1], rl.Color.white);
            const srcImage = try rl.loadImageFromTexture(texture.*);
            defer rl.unloadImage(srcImage);
            rl.imageDraw(&image, srcImage, sourceRect, dstRect, rl.Color.white);
            return image;
        },
        .entityType => |*entityTypeDocument| {
            const textureId = entityTypeDocument.getTextureId().* orelse return null;
            const texture = (self.requestTextureById(textureId) catch return null) orelse return null;

            const gridPosition = entityTypeDocument.getGridPosition().*;
            const cellSize = entityTypeDocument.getCellSize().*;
            const srcRectMin: @Vector(2, f32) = @floatFromInt(gridPosition * cellSize);
            const fCellSize: @Vector(2, f32) = @floatFromInt(cellSize);
            const srcRect = rl.Rectangle.init(
                srcRectMin[0],
                srcRectMin[1],
                fCellSize[0],
                fCellSize[1],
            );
            const dstRect = rl.Rectangle.init(0, 0, fCellSize[0], fCellSize[1]);
            var image = rl.genImageColor(cellSize[0], cellSize[1], rl.Color.white);
            const srcImage = try rl.loadImageFromTexture(texture.*);
            defer rl.unloadImage(srcImage);
            rl.imageDraw(&image, srcImage, srcRect, dstRect, rl.Color.white);
            return image;
        },
        .tilemap => |*tilemapDocument| {
            // 1. Calculate image size and create render texture
            const tileSize = tilemapDocument.getTileSize();
            const gridSize = tilemapDocument.getGridSize();
            const tilemapSize = gridSize * tileSize;
            const renderTexture = try rl.loadRenderTexture(tilemapSize[0], tilemapSize[1]);
            defer rl.unloadRenderTexture(renderTexture);

            // 2. Call draw tilemap with render texture as target
            rl.beginTextureMode(renderTexture);
            drawTilemap(self, tilemapDocument, .{ 0, 0 }, 1, true);
            rl.endTextureMode();

            // 3. Create image from renderTexture.texture
            var image = try rl.loadImageFromTexture(renderTexture.texture);
            rl.imageFlipVertical(&image);

            return image;
        },
        .scene => |*sceneDocument| {
            const entities = sceneDocument.getEntities();
            const tilemapId = for (entities.items) |entity|
                switch (entity.type) {
                    .tilemap => |tilemap| break tilemap.tilemapId orelse return null,
                    else => continue,
                }
            else
                return null;
            const tilemapDocument = (self.requestDocumentTypeById(.tilemap, tilemapId) catch return null) orelse return null;

            // 1. Calculate image size and create render texture
            const tileSize = tilemapDocument.getTileSize();
            const gridSize = tilemapDocument.getGridSize();
            const tilemapSize = gridSize * tileSize;
            const renderTexture = try rl.loadRenderTexture(tilemapSize[0], tilemapSize[1]);
            defer rl.unloadRenderTexture(renderTexture);

            // 2. Call draw tilemap with render texture as target
            rl.beginTextureMode(renderTexture);
            drawTilemap(self, tilemapDocument, .{ 0, 0 }, 1, true);
            rl.endTextureMode();

            // 3. Create image from renderTexture.texture
            var image = try rl.loadImageFromTexture(renderTexture.texture);
            rl.imageFlipVertical(&image);

            return image;
        },
    }
}
