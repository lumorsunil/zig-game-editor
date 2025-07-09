const std = @import("std");
const lib = @import("root").lib;
const Context = lib.Context;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const DocumentContent = lib.DocumentContent;
const ContextError = lib.ContextError;
const AssetIndex = lib.AssetIndex;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityTilemap = lib.documents.scene.SceneEntityTilemap;

pub fn newAsset(
    self: *Context,
    name: []const u8,
    comptime documentType: DocumentTag,
) !*std.meta.TagPayload(DocumentContent, documentType) {
    const p = &(self.currentProject orelse return ContextError.NoProject);
    const cd = p.assetsLibrary.currentDirectory orelse return ContextError.NoCurrentDirectory;
    var currentDir = try self.openCurrentDirectory();
    defer currentDir.close();

    const fileExtension = Document.getFileExtension(documentType);
    const fileName = try std.mem.concat(self.allocator, u8, &.{ name, fileExtension });
    defer self.allocator.free(fileName);
    const relativeToRoot = try std.fs.path.joinZ(self.allocator, &.{ cd, fileName });
    defer self.allocator.free(relativeToRoot);
    const normalized = AssetIndex.normalizeIndex(relativeToRoot);

    // TODO: Catch file already exists

    var document = Document.init();
    errdefer document.deinit(self.allocator);
    document.newContent(self.allocator, documentType);
    const documentId = document.getId();
    document.content.?.load(normalized);
    self.onNewAsset(&document) catch |err| {
        self.showError("Could not create {s} asset {s}: {}", .{ @tagName(documentType), normalized, err });
        return err;
    };

    self.documents.map.putAssumeCapacity(documentId, document);
    const storedDocument = self.documents.map.getPtr(documentId) orelse unreachable;
    const content = &@field(storedDocument.content.?, @tagName(documentType));
    errdefer _ = self.documents.map.swapRemove(documentId);

    p.assetIndex.addIndex(self.allocator, documentId, normalized);
    errdefer _ = p.assetIndex.removeIndex(self.allocator, documentId);

    storedDocument.save(p) catch |err| {
        self.showError("Could not save document {s}: {}", .{ normalized, err });
        return err;
    };

    p.assetsLibrary.appendNewFile(self.allocator, p.assetIndex, normalized);

    // Update the asset index to match the new path for the node id
    _ = self.saveIndex();

    return content;
}

fn onNewAsset(self: *Context, document: *Document) !void {
    // Special case for creating new scene documents;
    // Add a tilemap entity as the first entity.
    switch (document.content.?) {
        .scene => |*scene| {
            const entity = try self.allocator.create(SceneEntity);
            errdefer self.allocator.destroy(entity);
            entity.* = SceneEntity.init(
                .{ 0, 0 },
                .{ .tilemap = SceneEntityTilemap.init() },
            );
            try scene.getEntities().append(self.allocator, entity);
        },
        else => {},
    }
}
