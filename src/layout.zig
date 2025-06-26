const std = @import("std");
const Allocator = std.mem.Allocator;
const z = @import("zgui");
const c = @import("c");
const rl = @import("raylib");
const nfd = @import("nfd");
const lib = @import("root").lib;
const config = @import("root").config;
const Context = lib.Context;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const drawTilemap = lib.drawTilemap;
const Vector = lib.Vector;
const TileSource = lib.TileSource;
const TilemapLayer = lib.TilemapLayer;
const Action = lib.Action;
const Editor = lib.Editor;
const UUID = lib.UUIDSerializable;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityType = lib.documents.scene.SceneEntityType;
const SceneEntityExit = lib.documents.scene.SceneEntityExit;
const SceneEntityEntrance = lib.documents.scene.SceneEntityEntrance;
const SceneDocument = lib.documents.SceneDocument;
const TilemapDocument = lib.documents.TilemapDocument;
const AnimationDocument = lib.documents.AnimationDocument;
const assetsManager = @import("layout/assets-manager.zig").assetsManager;
const layouts = @import("layout/layouts.zig");
const utils = @import("layout/utils.zig");

pub fn layout(context: *Context) !void {
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));
    context.camera.offset.x = screenW / 2;
    context.camera.offset.y = screenH / 2;

    rl.clearBackground(context.backgroundColor);
    rl.beginMode2D(context.camera);

    if (context.getCurrentEditor()) |editor| {
        editorDraw(context, editor);
    }

    rl.endMode2D();

    c.rlImGuiBegin();

    if (context.currentProject) |_| {
        if (projectMenu(context)) {
            c.rlImGuiEnd();
            return;
        }

        documentTabs(context);

        if (context.getCurrentEditor()) |editor| {
            editorMenu(context, editor);
        }

        assetsManager(context);
    } else {
        noProjectOpenedMenu(context);
    }

    if (context.isErrorDialogOpen) {
        _ = z.begin("Error Message", .{ .flags = .{ .no_collapse = true } });
        z.textColored(.{ 1, 0, 0, 1 }, "{s}", .{context.errorMessage});
        if (z.button("Dismiss", .{})) context.isErrorDialogOpen = false;
        z.end();
    }

    c.rlImGuiEnd();

    if (context.updateThumbnailForCurrentDocument) {
        if (context.getCurrentEditor()) |editor| {
            context.updateThumbnailById(editor.document.getId());
        }
        context.updateThumbnailForCurrentDocument = false;
    }

    if (context.getCurrentEditor()) |editor| {
        if (!z.io.getWantCaptureMouse()) {
            editorHandleInput(context, editor);
        }
    }
}

const ProjectsMenuState = enum {
    render,
    abort,
};

fn projectMenu(context: *Context) bool {
    if (z.beginMainMenuBar()) {
        if (z.beginMenu("Projects", true)) {
            projectsMenu: switch (ProjectsMenuState.render) {
                .render => {
                    if (z.selectable("New Project", .{})) {
                        context.newProject();
                        continue :projectsMenu .abort;
                    }
                    if (z.selectable("Open Project", .{})) {
                        context.openProject();
                        continue :projectsMenu .abort;
                    }
                    if (z.selectable("Close Project", .{})) {
                        context.closeProject();
                        continue :projectsMenu .abort;
                    }
                    z.endMenu();
                },
                .abort => {
                    z.endMenu();
                    z.endMainMenuBar();
                    return true;
                },
            }
        }
        z.endMainMenuBar();
    }

    return false;
}

fn noProjectOpenedMenu(context: *Context) void {
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));

    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = screenW, .h = screenH });
    _ = z.begin("No Project Opened Menu", .{ .flags = .{ .no_title_bar = true, .no_resize = true, .no_collapse = true, .no_background = true, .no_move = true } });
    defer z.end();

    const buttonSize = 256;
    const buttonSpacing = 64;

    z.setCursorPos(.{ screenW / 2 - buttonSize - buttonSpacing, screenH / 2 - buttonSize / 2 });

    if (z.button("New Project", .{ .w = buttonSize, .h = buttonSize })) {
        context.newProject();
    }
    z.sameLine(.{ .spacing = buttonSpacing });
    if (z.button("Open Project", .{ .w = buttonSize, .h = buttonSize })) {
        context.openProject();
    }
}

fn editorDraw(context: *Context, editor: *Editor) void {
    layouts.draw(context, &editor.document);
}

fn editorMenu(context: *Context, editor: *Editor) void {
    layouts.menu(context, editor, &editor.document);
}

fn editorHandleInput(context: *Context, editor: *Editor) void {
    layouts.handleInput(context, editor, &editor.document);
}

fn demoButton(context: *Context) void {
    _ = z.begin("demo-button", .{});
    if (z.button("Demo", .{})) {
        context.isDemoWindowEnabled = true;
    }
    z.end();

    if (context.isDemoWindowEnabled) {
        z.showDemoWindow(&context.isDemoWindowOpen);
    }
}

fn documentTabs(context: *Context) void {
    const screenW: f32 = @floatFromInt(rl.getScreenWidth());
    z.setNextWindowPos(.{ .cond = .once, .x = 0, .y = 24 });
    z.setNextWindowSize(.{ .cond = .always, .w = screenW, .h = config.documentTabsHeight });
    _ = z.begin("Document Tabs", .{ .flags = .{ .no_title_bar = true, .no_resize = true, .no_move = true, .no_collapse = true } });
    defer z.end();

    if (z.beginTabBar("Opened Documents", .{ .reorderable = false, .no_close_with_middle_mouse_button = true })) {
        defer z.endTabBar();
        var it = context.openedEditors.map.iterator();
        var idToOpen: ?UUID = null;
        var idsToClose = std.BoundedArray(UUID, 256).init(0) catch unreachable;
        while (it.next()) |entry| {
            const id = entry.value_ptr.document.getId();
            const isActive = if (context.currentEditor) |ce| ce.uuid == id.uuid else false;
            const filePath = context.getFilePathById(id) orelse unreachable;
            z.pushStrId(&id.serialize());
            const shortName = utils.assetShortName(filePath);
            var open: bool = true;
            if (z.beginTabItem(
                @ptrCast(shortName),
                .{
                    .p_open = &open,
                    .flags = .{
                        .no_close_with_middle_mouse_button = true,
                        .set_selected = isActive,
                        .no_assumed_closure = true,
                    },
                },
            )) {
                defer z.endTabItem();
                if (z.isItemActive() and !isActive) {
                    idToOpen = id;
                }
            }
            z.popId();

            if (!open) {
                idsToClose.appendAssumeCapacity(id);
            }
        }
        if (idToOpen) |id| {
            context.openEditorById(id);
        }
        for (idsToClose.slice()) |id| {
            context.closeEditorById(id);
        }
    }
}
