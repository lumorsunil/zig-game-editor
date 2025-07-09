const lib = @import("root").lib;
const Context = lib.Context;
const Editor = lib.Editor;
const UUID = lib.UUIDSerializable;
const Node = lib.Node;

pub fn getCurrentEditor(self: *Context) ?*Editor {
    const id = self.currentEditor orelse return null;
    return self.openedEditors.map.getPtr(id);
}

pub fn closeEditorById(self: *Context, id: UUID) void {
    self.unloadDocumentById(id);
    var indexToOpen: ?usize = null;
    if (self.currentEditor) |ce| {
        if (ce.uuid == id.uuid) {
            self.currentEditor = null;

            const cei = for (self.openedEditors.map.keys(), 0..) |k, i| {
                if (k.uuid == id.uuid) {
                    break i;
                }
            } else unreachable;

            indexToOpen = if (cei == self.openedEditors.map.count() - 1) if (cei == 0) null else cei - 1 else cei;
        }
    }
    var entry = self.openedEditors.map.fetchOrderedRemove(id) orelse return;
    entry.value.deinit(self.allocator);
    if (indexToOpen) |i| {
        const idToOpen = self.openedEditors.map.keys()[i];
        self.openEditorById(idToOpen);
    }
}

pub fn closeEditorByNode(self: *Context, node: Node) void {
    switch (node) {
        .file => |file| {
            if (file.id) |id| self.closeEditorById(id);
        },
        .directory => {},
    }
}

pub fn closeEditors(self: *Context) void {
    for (self.openedEditors.map.values()) |*editor| {
        self.unloadDocumentById(editor.document.getId());
        editor.deinit(self.allocator);
    }

    self.openedEditors.map.clearAndFree(self.allocator);
    self.currentEditor = null;
}

pub fn openFileNode(self: *Context, file: Node.File) void {
    switch (file.documentType) {
        .scene, .tilemap, .animation, .entityType => {
            if (file.id) |id| self.openEditorById(id);
        },
        .texture => {},
    }
}

pub fn openEditorById(self: *Context, id: UUID) void {
    const entry = self.openedEditors.map.getOrPut(self.allocator, id) catch unreachable;

    if (!entry.found_existing) {
        if (self.requestDocumentById(id)) |document| {
            entry.value_ptr.* = Editor.init(document.*);
        } else {
            _ = self.openedEditors.map.swapRemove(id);
            self.currentEditor = null;
            return;
        }
    }

    self.currentEditor = id;
}

pub fn saveEditorFile(self: *Context, editor: *Editor) void {
    editor.saveFile(&self.currentProject.?) catch |err| {
        const filePath = self.getFilePathById(editor.document.getId());
        self.showError("Could not save file {?s}: {}", .{ filePath, err });
        return;
    };
}

pub fn deinitContextEditor(self: *Context) void {
    for (&self.tools) |*tool| tool.deinit(self.allocator);
}
