const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const SceneDocument = lib.documents.SceneDocument;
const TilemapDocument = lib.documents.TilemapDocument;
const AnimationDocument = lib.documents.AnimationDocument;
const TextureDocument = lib.documents.TextureDocument;
const EntityTypeDocument = lib.documents.EntityTypeDocument;
const DocumentGenericConfig = lib.documents.DocumentGenericConfig;
const Project = lib.Project;
const UUID = lib.UUIDSerializable;

pub const DocumentError = error{ FileExtensionInvalid, IndexNotFound };

const DocumentStateTag = enum {
    loaded,
    unloaded,
    err,
};

pub const DocumentState = union(DocumentStateTag) {
    loaded,
    unloaded,
    err: struct { err: anyerror },
};

pub const Document = struct {
    content: ?DocumentContent = null,
    state: anyerror!DocumentState,

    pub fn init() Document {
        return Document{
            .state = .unloaded,
        };
    }

    pub fn initWithError(err: anyerror) Document {
        return Document{
            .state = .{ .err = .{ .err = err } },
        };
    }

    pub fn deinit(self: *Document, allocator: Allocator) void {
        std.log.debug("1 Deinitializng document with state {any}", .{self.state});
        _ = self.state catch return;
        std.log.debug("2 Deinitializng document with state {any}", .{self.state});
        if (self.content) |*content| content.deinit(allocator);
        self.content = null;
        self.state = .unloaded;
    }

    pub fn getId(self: Document) UUID {
        return switch (self.content.?) {
            inline else => |content| content.getId(),
        };
    }

    pub fn open(
        allocator: Allocator,
        project: *Project,
        filePath: [:0]const u8,
    ) !Document {
        var document = Document.init();
        try document.loadContent(allocator, project, filePath);
        return document;
    }

    pub fn loadContent(
        self: *Document,
        allocator: Allocator,
        project: *Project,
        filePath: [:0]const u8,
    ) !void {
        //std.debug.assert(self.state == .unloaded or self.state == .err);
        const state = self.state catch |err| return err;
        std.debug.assert(state == .unloaded);
        errdefer |err| {
            std.log.err("Could not load document content for {s}: {}", .{ filePath, err });
            self.state = .{ .err = .{ .err = err } };
        }
        const documentType = try getTagByFilePath(filePath);
        switch (documentType) {
            inline else => |tag| {
                std.debug.assert(tag == documentType);

                var rootDir = project.assetsLibrary.openRoot();
                defer rootDir.close();
                const content = try DocumentContent.deserialize(allocator, rootDir, filePath, documentType);

                self.content = content;
                self.state = .loaded;
            },
        }
    }

    pub const DocumentSaveError = error{NoContent};

    pub fn save(self: Document, project: *Project) !void {
        const filePath = project.assetIndex.getIndex(self.getId()) orelse std.debug.panic("Could not save document {}: Could not find index", .{self.getId()});
        const state = self.state catch |err| return err;
        std.debug.assert(state == .loaded);
        if (self.content == null) return DocumentSaveError.NoContent;
        var rootDir = project.assetsLibrary.openRoot();
        defer rootDir.close();
        const file = rootDir.createFile(filePath, .{}) catch |err| {
            std.log.err("Could not save file {s}: {}", .{ filePath, err });
            return err;
        };
        defer file.close();
        const writer = file.writer();
        try self.content.?.serialize(writer);
    }

    pub fn newContent(
        self: *Document,
        allocator: Allocator,
        comptime documentType: DocumentTag,
    ) void {
        const isOk = if (self.state) |state| state != .loaded else |_| true;
        std.debug.assert(isOk);
        self.content = DocumentContent.init(allocator, documentType);
        self.state = .loaded;
    }

    pub fn getFileFilter(tag: DocumentTag) [:0]const u8 {
        return switch (tag) {
            .scene => "scene.json",
            .tilemap => "tilemap.json",
            .animation => "animations.json",
            .texture => "texture.json",
            .entityType => "entity-type.json",
        };
    }

    pub fn getFileExtension(tag: DocumentTag) [:0]const u8 {
        return switch (tag) {
            inline else => |t| "." ++ comptime getFileFilter(t),
        };
    }

    pub fn getTypeLabel(tag: DocumentTag) [:0]const u8 {
        return switch (tag) {
            .scene => "Scene",
            .tilemap => "Tilemap",
            .animation => "Animation",
            .texture => "Texture",
            .entityType => "Entity Type",
        };
    }

    pub fn getTagByFilePath(filePath: []const u8) !DocumentTag {
        for (std.meta.tags(DocumentTag)) |tag| {
            const extension = Document.getFileExtension(tag);
            if (std.mem.endsWith(u8, filePath, extension)) return tag;
        }

        return DocumentError.FileExtensionInvalid;
    }
};

pub const DocumentTag = enum {
    scene,
    tilemap,
    animation,
    texture,
    entityType,
};

pub const DocumentContent = union(DocumentTag) {
    scene: SceneDocument,
    tilemap: TilemapDocument,
    animation: AnimationDocument,
    texture: TextureDocument,
    entityType: EntityTypeDocument,

    pub fn init(allocator: Allocator, comptime documentType: DocumentTag) DocumentContent {
        return switch (documentType) {
            inline else => |d| @unionInit(DocumentContent, @tagName(d), std.meta.TagPayload(DocumentContent, documentType).init(allocator)),
        };
    }

    pub fn deinit(self: *DocumentContent, allocator: Allocator) void {
        switch (self.*) {
            inline else => |*d| d.deinit(allocator),
        }
    }

    pub fn load(self: *DocumentContent, path: [:0]const u8) void {
        switch (self.*) {
            inline else => |*d| d.document.load(path),
        }
    }

    pub fn serialize(self: DocumentContent, writer: anytype) !void {
        switch (self) {
            inline else => |d| try d.document.serialize(writer),
        }
    }

    pub fn deserialize(
        allocator: Allocator,
        dir: std.fs.Dir,
        path: [:0]const u8,
        documentType: DocumentTag,
    ) !DocumentContent {
        return switch (documentType) {
            inline else => |d| @unionInit(DocumentContent, @tagName(d), .{ .document = try DocumentPayload(d).DocumentType.deserialize(allocator, dir, path) }),
        };
    }

    pub fn getFileFilter(comptime tag: DocumentTag) []const u8 {
        if (!@hasDecl(DocumentPayload(tag), "fileFilter")) @compileError("DocumentContent " ++ @tagName(tag) ++ " does not implement the declaration fileFilter");
        return DocumentPayload(tag).fileFilter;
    }
};

pub fn DocumentPayload(comptime tag: DocumentTag) type {
    return std.meta.TagPayload(DocumentContent, tag);
}
