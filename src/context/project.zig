const std = @import("std");
const lib = @import("root").lib;
const Context = lib.Context;
const ContextError = lib.ContextError;
const Project = lib.Project;

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
}

pub fn deinitContextProject(self: *Context) void {
    self.setProject(null);
}
