const std = @import("std");
const lib = @import("root").lib;
const Context = lib.Context;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const DocumentContent = lib.DocumentContent;
const Project = lib.Project;
const ContextError = lib.ContextError;
const AssetIndex = lib.AssetIndex;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityTilemap = lib.documents.scene.SceneEntityTilemap;

pub const NewAssetError = error{AlreadyExists};

pub fn newAsset(
    self: *Context,
    name: []const u8,
    comptime documentType: DocumentTag,
) !struct { *Document, *std.meta.TagPayload(DocumentContent, documentType) } {
    const project, const currentDirectory = try self.getProjectAndCurrentDirectory();

    const normalized = try getNormalizedAssetPath(self, currentDirectory, name, documentType);
    defer self.allocator.free(normalized);

    try self.checkFileExists(project, normalized);

    var document = try self.createDocument(documentType, normalized);
    errdefer document.deinit(self.allocator);
    const documentId = document.getId();

    try self.storeDocument(project, document, normalized);

    const storedDocument = self.documents.map.getPtr(documentId) orelse unreachable;
    const content = &@field(storedDocument.content.?, @tagName(documentType));

    return .{ storedDocument, content };
}

fn getProjectAndCurrentDirectory(self: *Context) !struct { *Project, [:0]const u8 } {
    const project = &(self.currentProject orelse return ContextError.NoProject);
    const currentDirectory = project.assetsLibrary.currentDirectory orelse return ContextError.NoCurrentDirectory;

    return .{ project, currentDirectory };
}

fn getNormalizedAssetPath(
    self: *Context,
    currentDirectory: []const u8,
    assetName: []const u8,
    comptime documentType: DocumentTag,
) ![:0]const u8 {
    const fileExtension = Document.getFileExtension(documentType);
    const fileName = try std.mem.concat(self.allocator, u8, &.{ assetName, fileExtension });
    defer self.allocator.free(fileName);
    const relativeToRoot = try std.fs.path.joinZ(self.allocator, &.{
        currentDirectory,
        fileName,
    });
    defer self.allocator.free(relativeToRoot);
    return try self.allocator.dupeZ(u8, AssetIndex.normalizeIndex(relativeToRoot));
}

fn checkFileExists(self: *Context, project: *Project, filePath: []const u8) !void {
    var dir = project.assetsLibrary.openRoot();
    defer dir.close();

    if (dir.openFile(filePath, .{}) catch |err|
        switch (err) {
            error.FileNotFound => null,
            else => {
                self.showError("Could not access file {s}: {}", .{ filePath, err });
                return err;
            },
        }) |f|
    {
        self.showError("File already exists: {s}", .{filePath});
        f.close();
        return NewAssetError.AlreadyExists;
    }
}

fn createDocument(
    self: *Context,
    comptime documentType: DocumentTag,
    filePath: [:0]const u8,
) !Document {
    var document = Document.init();
    errdefer document.deinit(self.allocator);
    document.newContent(self.allocator, documentType);
    document.content.?.load(filePath);
    self.onNewAsset(&document) catch |err| {
        self.showError("Could not create {s} asset {s}: {}", .{ @tagName(documentType), filePath, err });
        return err;
    };

    return document;
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

fn storeDocument(
    self: *Context,
    project: *Project,
    document: Document,
    filePath: [:0]const u8,
) !void {
    const documentId = document.getId();

    self.documents.map.putAssumeCapacity(documentId, document);
    errdefer _ = self.documents.map.swapRemove(documentId);

    project.assetIndex.addIndex(self.allocator, documentId, filePath);
    errdefer _ = project.assetIndex.removeIndex(self.allocator, documentId);

    document.save(project) catch |err| {
        self.showError("Could not save document {s}: {}", .{ filePath, err });
        return err;
    };

    project.assetsLibrary.appendNewFile(self.allocator, project.assetIndex, filePath);

    _ = self.saveIndex();
}
