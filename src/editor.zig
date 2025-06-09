const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const nfd = @import("nfd");

pub const Editor = struct {
    documentType: DocumentTag,
    document: Document,

    pub fn init(document: Document) Editor {
        return Editor{
            .documentType = document.content.?,
            .document = document,
        };
    }

    pub fn deinit(_: *Editor, _: Allocator) void {}

    fn getFileFilter(self: Editor) []const u8 {
        return self.document.getFileFilter(self.documentType);
    }

    fn getFileExtension(self: Editor) []const u8 {
        return self.document.getFileExtension(self.documentType);
    }

    fn createDocumentData(self: Editor, allocator: Allocator) Document {
        self.document.deinit(allocator);
        self.document = Document.init();
        // const entity = self.allocator.create(SceneEntity) catch unreachable;
        // entity.* = SceneEntity.init(self.allocator, .{ 0, 0 }, .{ .tilemap = SceneEntityTilemap.init() });
        // ptr.persistentData.entities.append(self.allocator, entity) catch unreachable;
        return Document;
    }

    fn createDefaultDocumentData(self: Editor) *Document {
        return self.createDocumentData();
    }

    pub fn newFile(self: *Editor) void {
        self.freeDocumentData();
        self.document = self.createDefaultDocumentData();
    }

    // pub fn openFile(allocator: Allocator, initialPath: []const u8) !Editor {
    //     const maybeFileName = try nfd.openFileDialog(self.getFileFilter(), initialPath);
    //
    //     if (maybeFileName) |fileName| {
    //         defer nfd.freePath(fileName);
    //         try openFileEx(allocator, fileName);
    //     }
    // }

    pub fn openFileEx(allocator: Allocator, filePath: [:0]const u8) !Editor {
        const documentType = try Document.getTagByFilePath(filePath);
        const document = try Document.open(allocator, filePath, documentType);

        return Editor{
            .documentType = documentType,
            .document = document,
        };
    }

    pub fn saveFile(self: *Editor) !void {
        try self.document.save();
    }
};
