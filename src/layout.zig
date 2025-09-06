const std = @import("std");
const z = @import("zgui");
const c = @import("c").c;
const rl = @import("raylib");
const lib = @import("lib");
const config = @import("lib").config;
const Context = lib.Context;
const Vector = lib.Vector;
const Editor = lib.Editor;
const UUID = lib.UUIDSerializable;
const assetsManager = lib.layouts.assetsManager.assetsManager;
const layouts = lib.layouts.generic;
const utils = lib.layouts.utils;
const projectLayout = lib.layouts.project;
const sceneMapUI = lib.layouts.sceneMap.sceneMapUI;
const sceneMapUIHandleInput = lib.layouts.sceneMap.sceneMapUIHandleInput;
const BoundedArray = lib.BoundedArray;

pub fn layout(context: *Context) !void {
    startOfFrame(context);

    {
        rl.clearBackground(context.backgroundColor);

        if (context.getCurrentEditor()) |editor| {
            rl.beginMode2D(editor.camera);
            defer rl.endMode2D();
            editorDraw(context, editor);
        }
    }

    {
        c.rlImGuiBegin();
        defer c.rlImGuiEnd();

        if (imguiUI(context)) {
            return;
        }
    }

    if (context.getCurrentEditor()) |editor| {
        const imguiWantsKeyboard = z.io.getWantCaptureKeyboard() and z.getDragDropPayload() == null;
        if (!z.io.getWantCaptureMouse() and !imguiWantsKeyboard) {
            editorHandleInput(context, editor);
        }
    }

    sceneMapUIHandleInput(context);

    endOfFrame(context);
}

/// Returns true if we need to abort rendering the frame and continue to the next frame
fn imguiUI(context: *Context) bool {
    if (context.currentProject) |*p| {
        if (projectLayout.projectMenu(context, p)) {
            return true;
        }

        documentTabs(context);

        if (context.getCurrentEditor()) |editor| {
            editorMenu(context, editor);
        }

        assetsManager(context);

        sceneMapUI(context);
    } else {
        projectLayout.noProjectOpenedMenu(context);
    }

    errorDialog(context);

    return false;
}

fn errorDialog(context: *Context) void {
    if (context.isErrorDialogOpen) {
        _ = z.begin("Error Message", .{ .flags = .{ .no_collapse = true } });
        defer z.end();

        z.textColored(.{ 1, 0, 0, 1 }, "{s}", .{context.errorMessage});
        if (z.button("Dismiss", .{})) context.isErrorDialogOpen = false;
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

fn startOfFrame(context: *Context) void {
    updateCameraOffset(context);
    if (context.playState == .startNextFrame) {
        context.playState = .starting;
    } else if (context.playState == .starting) {
        context.play();
    }
}

fn updateCameraOffset(context: *Context) void {
    const editor = context.getCurrentEditor() orelse return;
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));
    editor.camera.offset.x = screenW / 2;
    editor.camera.offset.y = screenH / 2;
}

fn endOfFrame(context: *Context) void {
    if (context.updateThumbnailForCurrentDocument) {
        if (context.getCurrentEditor()) |editor| {
            context.updateThumbnailById(editor.document.getId());
        }
        context.updateThumbnailForCurrentDocument = false;
    }

    context.handleEditorsToBeClosed();

    if (context.editorToBeOpened) |id| {
        context.openEditorById(id);
        context.editorToBeOpened = null;
    }
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
        var idsToClose = BoundedArray(UUID, 256).empty;
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

            if (z.beginPopupContextItem()) {
                defer z.endPopup();
                documentTabContextMenu(context, id, &idsToClose);
            }

            if (!open) {
                idsToClose.append(id);
            }
        }
        if (idToOpen) |id| {
            context.openEditorById(id);
        }
        context.setEditorsToBeClosedByIds(idsToClose.slice());
    }
}

fn documentTabContextMenu(context: *Context, id: UUID, idsToClose: *BoundedArray(UUID, 256)) void {
    if (z.selectable("Close All But This", .{})) {
        for (context.openedEditors.map.values()) |editor| {
            const eid = editor.document.getId();
            if (id.uuid != eid.uuid) {
                idsToClose.append(eid);
            }
        }
    }
    if (z.selectable("Close To The Left", .{})) {
        const i = for (context.openedEditors.map.values(), 0..) |editor, i| {
            if (editor.document.getId().uuid == id.uuid) break i;
        } else return;
        const idsToTheLeft = context.openedEditors.map.keys()[0..i];
        idsToClose.appendSlice(idsToTheLeft);
    }
    if (z.selectable("Close To The Right", .{})) {
        const i = for (context.openedEditors.map.values(), 0..) |editor, i| {
            if (editor.document.getId().uuid == id.uuid) break i;
        } else return;
        if (i == context.openedEditors.map.count() - 1) return;
        const idsToTheRight = context.openedEditors.map.keys()[i + 1 ..];
        idsToClose.appendSlice(idsToTheRight);
    }
    if (z.selectable("Close All", .{})) {
        for (context.openedEditors.map.values()) |editor| {
            idsToClose.append(editor.document.getId());
        }
    }
}
