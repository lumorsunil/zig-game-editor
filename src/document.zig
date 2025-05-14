const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const SceneDocument = lib.documents.SceneDocument;
const TilemapDocument = lib.documents.TilemapDocument;
const AnimationDocument = lib.documents.AnimationDocument;
const TextureDocument = lib.documents.TextureDocument;

pub const Document = struct {
    // TODO: Remove nullable when we have assets manager
    filePath: [:0]const u8,
    content: ?DocumentContent = null,

    pub fn init(allocator: Allocator, filePath: [:0]const u8) Document {
        return Document{
            .filePath = allocator.dupeZ(u8, filePath) catch unreachable,
        };
    }

    pub fn deinit(self: *Document, allocator: Allocator) void {
        allocator.free(self.filePath);
        if (self.content) |*content| content.deinit(allocator);
        self.content = null;
    }

    pub fn open(
        allocator: Allocator,
        filePath: [:0]const u8,
        documentType: DocumentTag,
    ) !Document {
        const file = std.fs.openFileAbsolute(filePath, .{}) catch |err| {
            std.log.err("Could not open file {s}: {}", .{ filePath, err });
            return err;
        };
        defer file.close();
        const fileReader = file.reader();
        var reader = std.json.reader(allocator, fileReader);
        defer reader.deinit();
        const content = DocumentContent.deserialize(allocator, filePath, &reader, documentType) catch |err| {
            std.log.err("Error reading file: {s} {}", .{ filePath, err });
            return err;
        };

        var document = Document.init(allocator, filePath);
        document.content = content;

        return document;
    }

    pub const DocumentSaveError = error{NoContent};

    pub fn save(self: Document) !void {
        if (self.content == null) return DocumentSaveError.NoContent;
        const file = std.fs.createFileAbsolute(self.filePath, .{}) catch |err| {
            std.log.err("Could not save file {s}: {}", .{ self.filePath, err });
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
        self.content = DocumentContent.init(allocator, documentType);
    }

    pub fn getFileFilter(tag: DocumentTag) [:0]const u8 {
        return switch (tag) {
            .scene => "scene.json",
            .tilemap => "tilemap.json",
            .animation => "animations.json",
            .texture => "png",
        };
    }

    pub fn getFileExtension(tag: DocumentTag) [:0]const u8 {
        return switch (tag) {
            .scene => ".scene.json",
            .tilemap => ".tilemap.json",
            .animation => ".animations.json",
            .texture => ".png",
        };
    }

    pub fn getTypeLabel(tag: DocumentTag) [:0]const u8 {
        return switch (tag) {
            .scene => "Scene",
            .tilemap => "Tilemap",
            .animation => "Animation",
            .texture => "Texture",
        };
    }

    pub fn getTagByFilePath(filePath: []const u8) DocumentTag {
        inline for (std.meta.tags(DocumentTag)) |tag| {
            const extension = Document.getFileExtension(tag);
            if (std.mem.endsWith(u8, filePath, extension)) return tag;
        }

        std.debug.panic("Could not get document type from file path: {s}", .{filePath});
    }
};

pub const DocumentContent = union(enum) {
    scene: SceneDocument,
    tilemap: TilemapDocument,
    animation: AnimationDocument,
    texture: TextureDocument,

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

    pub fn load(self: *Document) void {
        switch (self.content.?) {
            inline else => |*d| d.load(),
        }
    }

    pub fn serialize(self: DocumentContent, writer: anytype) !void {
        switch (self) {
            inline else => |d| try d.document.serialize(writer),
        }
    }

    pub fn deserialize(
        allocator: Allocator,
        path: [:0]const u8,
        reader: anytype,
        documentType: DocumentTag,
    ) !DocumentContent {
        return switch (documentType) {
            inline else => |d| @unionInit(DocumentContent, @tagName(d), .{ .document = try DocumentPayload(d).DocumentType.deserialize(allocator, path, reader) }),
        };
    }

    pub fn getFileFilter(comptime tag: DocumentTag) []const u8 {
        if (!@hasDecl(DocumentPayload(tag), "fileFilter")) @compileError("DocumentContent " ++ @tagName(tag) ++ " does not implement the declaration fileFilter");
        return DocumentPayload(tag).fileFilter;
    }
};

pub const DocumentTag = std.meta.Tag(DocumentContent);

pub fn DocumentPayload(comptime tag: DocumentTag) type {
    return std.meta.TagPayload(DocumentContent, tag);
}
