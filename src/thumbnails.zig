const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const IdArrayHashMap = lib.IdArrayHashMap;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const rl = @import("raylib");

pub const thumbnailSize = 64;
const iconSize = 128;

pub const ThumbnailResult = union(enum) {
    success: rl.Texture2D,
    err: anyerror,

    pub fn deinit(self: ThumbnailResult) void {
        switch (self) {
            .success => |texture| rl.unloadTexture(texture),
            .err => {},
        }
    }
};

pub const Thumbnails = struct {
    cache: IdArrayHashMap(ThumbnailResult),

    pub const empty: Thumbnails = .{
        .cache = .empty,
    };

    pub fn init() Thumbnails {
        return Thumbnails{
            .cache = .empty,
        };
    }

    pub fn deinit(self: *Thumbnails, allocator: Allocator) void {
        for (self.cache.map.values()) |result| result.deinit();
        self.cache.deinit(allocator);
    }

    pub fn requestById(
        self: *Thumbnails,
        allocator: Allocator,
        id: UUID,
        cacheDirectory: []const u8,
    ) !?*rl.Texture2D {
        const cached = self.cache.map.getOrPut(allocator, id) catch unreachable;

        if (!cached.found_existing) {
            const filePath = getFilePath(allocator, cacheDirectory, id);
            defer allocator.free(filePath);
            cached.value_ptr.* = .{
                .success = rl.loadTexture(filePath) catch |err| {
                    cached.value_ptr.* = .{ .err = err };
                    return err;
                },
            };
        }

        switch (cached.value_ptr.*) {
            .success => |*texture| return texture,
            .err => |err| return err,
        }
    }

    pub const UpdateError = error{ExportImageFailed};

    pub fn updateById(
        self: *Thumbnails,
        allocator: Allocator,
        id: UUID,
        cacheDirectory: []const u8,
        image: rl.Image,
    ) !void {
        // Create scaled version of texture
        const imageSize: @Vector(2, f32) = .{
            @as(f32, @floatFromInt(image.width)),
            @as(f32, @floatFromInt(image.height)),
        };
        const thumbnailSizeV = @Vector(2, f32){ thumbnailSize, thumbnailSize };
        const destSize = @min(imageSize, thumbnailSizeV);
        const srcRect = rl.Rectangle.init(0, 0, imageSize[0], imageSize[1]);
        const dstRect = rl.Rectangle.init(0, 0, destSize[0], destSize[1]);

        var thumbnailImage = rl.genImageColor(
            @intFromFloat(destSize[0]),
            @intFromFloat(destSize[1]),
            rl.Color.white,
        );
        defer rl.unloadImage(thumbnailImage);

        rl.imageDraw(&thumbnailImage, image, srcRect, dstRect, rl.Color.white);

        // Persist thumbnail to file system
        const filePath = getFilePath(allocator, cacheDirectory, id);
        defer allocator.free(filePath);
        if (!rl.exportImage(thumbnailImage, filePath)) return UpdateError.ExportImageFailed;

        const renderTexture = rl.loadRenderTexture(iconSize, iconSize) catch unreachable;
        defer rl.unloadRenderTexture(renderTexture);

        const tempThumbnailTexture = rl.loadTextureFromImage(thumbnailImage) catch unreachable;
        rl.setTextureFilter(tempThumbnailTexture, .point);
        defer rl.unloadTexture(tempThumbnailTexture);

        // var scaledImage = rl.genImageColor(iconSize, iconSize, rl.Color.white);
        // defer rl.unloadImage(scaledImage);

        //rl.imageResizeNN(&thumbnailImage, iconSize, iconSize);
        const iconDestRect = rl.Rectangle.init(0, 0, iconSize, iconSize);
        // rl.imageDraw(&scaledImage, image, srcRect, iconDestRect, rl.Color.white);
        rl.beginTextureMode(renderTexture);
        rl.drawTexturePro(
            tempThumbnailTexture,
            dstRect,
            iconDestRect,
            rl.Vector2.init(0, 0),
            0,
            rl.Color.white,
        );
        rl.endTextureMode();

        // Store thumbnail in cache
        // const thumbnailTexture = rl.loadTextureFromImage(scaledImage) catch |err| {
        //     self.put(allocator, id, .{ .err = err });
        //     return;
        // };

        var actualThumbnailImage = rl.loadImageFromTexture(renderTexture.texture) catch unreachable;
        rl.imageFlipVertical(&actualThumbnailImage);
        defer rl.unloadImage(actualThumbnailImage);
        const thumbnailTexture = rl.loadTextureFromImage(actualThumbnailImage) catch unreachable;

        rl.setTextureFilter(thumbnailTexture, .point);

        self.put(allocator, id, .{ .success = thumbnailTexture });
    }

    fn put(self: *Thumbnails, allocator: Allocator, id: UUID, result: ThumbnailResult) void {
        const previous = self.cache.map.fetchPut(allocator, id, result) catch unreachable orelse return;
        previous.value.deinit();
    }

    /// Caller owns return pointer
    fn getFilePath(
        allocator: Allocator,
        cacheDirectory: []const u8,
        id: UUID,
    ) [:0]const u8 {
        const fileName = std.fmt.allocPrint(allocator, "{f}.png", .{id}) catch unreachable;
        defer allocator.free(fileName);
        return std.fs.path.joinZ(allocator, &.{ cacheDirectory, fileName }) catch unreachable;
    }
};
