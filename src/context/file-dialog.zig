const nfd = @import("nfd");
const lib = @import("root").lib;
const Context = lib.Context;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;

pub fn selectFolder(self: *Context) ?[]const u8 {
    const folder = (nfd.openFolderDialog(null) catch return null) orelse return null;
    defer nfd.freePath(folder);
    return self.allocator.dupe(u8, folder) catch unreachable;
}

pub fn openFileWithDialog(self: *Context, documentType: DocumentTag) ?Document {
    const fileName = (nfd.openFileDialog(Document.getFileFilter(documentType), null) catch return null) orelse return null;
    defer nfd.freePath(fileName);
    const id = self.getIdByFilePath(fileName) orelse return null;
    const document = self.requestDocumentById(id) orelse return null;
    return document.*;
}

pub fn getFileNameWithDialog(self: *Context, fileFilter: ?[:0]const u8) ?[:0]const u8 {
    const fileName = (nfd.openFileDialog(fileFilter, null) catch return null) orelse return null;
    defer nfd.freePath(fileName);
    return self.allocator.dupeZ(u8, fileName) catch unreachable;
}
