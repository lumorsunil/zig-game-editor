const std = @import("std");
const lib = @import("lib");
const Context = lib.Context;
const ContextError = lib.ContextError;
const UUID = lib.UUIDSerializable;
const DocumentTag = lib.DocumentTag;
const Node = lib.Node;

pub fn openCurrentDirectory(self: *Context) !std.fs.Dir {
    const p = self.currentProject orelse return ContextError.NoProject;
    return p.assetsLibrary.openCurrentDirectory(self.allocator) catch |err| {
        self.showError("Could not open current directory {?s}: {}", .{ p.assetsLibrary.currentDirectory, err });
        return err;
    };
}

pub fn setCurrentDirectory(self: *Context, path: [:0]const u8) void {
    self.currentProject.?.setCurrentDirectory(self.allocator, path) catch |err| {
        self.showError("Could not set current directory {s}: {}", .{ path, err });
        return;
    };
}

pub fn getIdByFilePath(self: *Context, filePath: [:0]const u8) ?UUID {
    const p = self.currentProject orelse return null;
    return p.assetIndex.getId(filePath);
}

pub fn getFilePathById(self: *Context, id: UUID) ?[:0]const u8 {
    const p = self.currentProject orelse return null;
    return p.assetIndex.getIndex(id);
}

pub fn getIdsByDocumentType(self: *Context, comptime documentType: DocumentTag) []UUID {
    const p = &(self.currentProject orelse return &.{});
    return p.assetIndex.getIdsByDocumentType(self.allocator, documentType);
}

pub fn getNodeById(self: *Context, id: UUID) ?Node {
    const p = self.currentProject orelse return null;
    return p.assetsLibrary.getNodeById(id);
}

pub fn openNewDirectoryDialog(context: *Context) void {
    context.isNewDirectoryDialogOpen = true;
    context.isDialogFirstRender = true;
}

pub fn openNewAssetDialog(context: *Context, documentType: DocumentTag) void {
    context.isNewAssetDialogOpen = documentType;
    context.isDialogFirstRender = true;
}

pub fn closeNewAssetAndDirectoryDialog(context: *Context) void {
    context.isNewDirectoryDialogOpen = false;
    context.isNewAssetDialogOpen = null;
    context.isDialogFirstRender = false;
    context.newAssetInputTarget = null;
    context.reusableTextBuffer[0] = 0;
}
