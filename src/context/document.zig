const std = @import("std");
const rl = @import("raylib");
const lib = @import("lib");
const Context = lib.Context;
const ContextError = lib.ContextError;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const DocumentContent = lib.DocumentContent;
const DocumentError = lib.DocumentError;
const UUID = lib.UUIDSerializable;

pub fn requestDocumentById(self: *Context, id: UUID) ?*Document {
    const entry = self.documents.map.getOrPutAssumeCapacity(id);

    if (!entry.found_existing) {
        std.log.debug("Requested document {f} not found, loading", .{id});

        const path = self.getFilePathById(id) orelse {
            entry.value_ptr.* = .initWithError(DocumentError.IndexNotFound);
            self.showError("Could not find document in index with id {f}", .{id});
            return null;
        };
        entry.value_ptr.* = Document.open(self.allocator, &self.currentProject.?, path) catch |err| {
            self.showError("Could not open document {s}: {}", .{ path, err });
            return null;
        };
    } else if (if (entry.value_ptr.state) |state| state == .unloaded else |_| false) {
        std.log.debug("Requested document {} found with no content, loading", .{id});
        const filePath = self.getFilePathById(id) orelse return null;
        std.log.debug("Loading content for document {?s}", .{filePath});
        entry.value_ptr.loadContent(self.allocator, &self.currentProject.?, filePath) catch |err| {
            self.showError("Could not load document: {}", .{err});
            return null;
        };
    } else {
        _ = entry.value_ptr.state catch return null;
    }

    return entry.value_ptr;
}

pub fn requestDocumentTypeById(
    self: *Context,
    comptime tag: DocumentTag,
    id: UUID,
) !?*std.meta.TagPayload(DocumentContent, tag) {
    const document = self.requestDocumentById(id) orelse return null;

    switch (document.content.?) {
        tag => |*content| return content,
        else => return ContextError.DocumentTagNotMatching,
    }
}

pub fn requestTextureById(self: *Context, id: UUID) !?*rl.Texture2D {
    const content = try self.requestDocumentTypeById(.texture, id) orelse return null;
    return content.getTexture();
}

pub fn unloadDocumentById(self: *Context, id: UUID) void {
    var entry = self.documents.map.fetchSwapRemove(id) orelse return;
    entry.value.deinit(self.allocator);
}

pub fn unloadDocuments(self: *Context) void {
    for (self.documents.map.values()) |*document| {
        document.deinit(self.allocator);
    }

    self.documents.map.clearAndFree(self.allocator);
}

pub fn reloadDocumentById(self: *Context, id: UUID) void {
    self.unloadDocumentById(id);
    _ = self.requestDocumentById(id);
}

pub fn saveDocument(self: *Context, id: UUID) void {
    const p = &self.currentProject orelse return;
    const editor = self.openedEditors.map.getPtr(id) orelse return;
    editor.saveFile(p) catch |err| {
        const filePath = self.getFilePathById(id);
        self.showError("Could not save file {?s}: {}", .{ filePath, err });
        return;
    };
}

pub fn saveAll(self: *Context) void {
    for (self.openedEditors.map.values()) |*editor| {
        self.saveEditorFile(editor);
    }
}
