const std = @import("std");
const lib = @import("lib");
const Context = lib.Context;
const ContextError = lib.ContextError;
const Project = lib.Project;
const ProjectOptions = lib.ProjectOptions;
const Vector = lib.Vector;

pub fn newProject(self: *Context) void {
    const folder = self.selectFolder() orelse return;
    defer self.allocator.free(folder);
    self.setProject(.init(self.allocator, folder));
}

pub fn openProject(self: *Context) void {
    const folder = self.selectFolder() orelse return;
    defer self.allocator.free(folder);
    self.setProject(.init(self.allocator, folder));
}

pub fn saveProject(self: *Context) !void {
    const p = &(self.currentProject orelse return ContextError.NoProject);
    try p.saveOptions(self.allocator);
}

pub fn closeProject(self: *Context) void {
    self.setProject(null);
}

pub fn setProject(self: *Context, project: ?Project) void {
    if (self.currentProject) |*p| {
        self.closeEditors();
        p.deinit(self.allocator);
        self.unloadDocuments();
    }

    self.currentProject = project;

    if (self.currentProject) |_| {
        self.loadProject() catch |err| {
            self.showError("Could not load project: {}", .{err});
        };
    }
}

/// Project needs to be set before this is called.
fn loadProject(self: *Context) !void {
    const p = &(self.currentProject orelse return ContextError.NoProject);
    self.documents.map.ensureTotalCapacity(self.allocator, 100000) catch unreachable;
    p.loadOptions(self.allocator) catch |err| {
        std.log.err("Could not load project options: {}", .{err});
    };
    p.loadIndex(self.allocator) catch |err| {
        std.log.err("Could not load/build asset index: {}", .{err});
    };
    self.setCurrentDirectory(".");
    self.sceneMap.generate(self) catch |err| {
        std.log.err("Could not generate scene map: {}", .{err});
    };
}

pub fn deinitContextProject(self: *Context) void {
    self.setProject(null);
}

pub fn upgradeProject(self: *Context) void {
    const p = &(self.currentProject orelse return);

    for (p.assetIndex.hashMap.map.keys()) |id| {
        const document = self.requestDocumentById(id) orelse continue;
        document.save(p) catch |err| {
            self.showError("Could not upgrade document {?s}: {}", .{ self.getFilePathById(id), err });
            return;
        };
    }
}

const defaultTileSize: Vector = std.meta.fieldInfo(
    ProjectOptions,
    .tileSize,
).defaultValue() orelse .{ 16, 16 };

pub fn getTileSize(self: *Context) Vector {
    const p = &(self.currentProject orelse return defaultTileSize);
    return p.options.tileSize;
}

const defaultTilesetPadding: u32 = std.meta.fieldInfo(
    ProjectOptions,
    .tilesetPadding,
).defaultValue() orelse 4;

pub fn getTilesetPadding(self: *Context) u32 {
    const p = &(self.currentProject orelse return 4);
    return p.options.tilesetPadding;
}
