const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c");
const lib = @import("root").lib;
const config = @import("root").config;
const LayoutGeneric = lib.LayoutGeneric;
const Context = lib.Context;
const Editor = lib.Editor;
const EntityTypeDocument = lib.documents.EntityTypeDocument;
const Vector = lib.Vector;
const Node = lib.Node;
const utils = @import("utils.zig");

pub const LayoutEntityType = LayoutGeneric(.entityType, draw, menu, handleInput);

fn draw(context: *Context, entityTypeDocument: *EntityTypeDocument) void {
    const textureId = entityTypeDocument.getTextureId() orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;
    rl.drawTextureEx(texture.*, .{ .x = 0, .y = 0 }, 0, @floatFromInt(context.scale), rl.Color.white);
}

fn menu(context: *Context, editor: *Editor, entityTypeDocument: *EntityTypeDocument) void {
    const screenSize: @Vector(2, f32) = @floatFromInt(Vector{ rl.getScreenWidth(), rl.getScreenHeight() });
    z.setNextWindowPos(.{ .x = 0, .y = config.topBarOffset });
    z.setNextWindowSize(.{ .w = 200, .h = screenSize[1] - config.topBarOffset });
    _ = z.begin("Entity Type Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
    } });
    defer z.end();

    utils.activeDocumentLabel(context, editor);

    if (z.button("Reset Camera", .{})) {
        utils.resetCamera(context);
    }
    z.text("{d:0.0},{d:0.0}", .{ context.camera.target.x, context.camera.target.y });

    if (z.button("Save", .{})) {
        context.saveEditorFile(editor);
        context.updateThumbnailById(entityTypeDocument.getId());
    }
    z.text("ID: {s}", .{std.json.fmt(entityTypeDocument.getId(), .{})});
    if (z.isItemHovered(.{ .delay_short = true })) {
        if (z.beginTooltip()) {
            z.text("{s}", .{std.json.fmt(entityTypeDocument.getId(), .{})});
        }
        z.endTooltip();
    }
    _ = z.inputText("Name", .{
        .buf = entityTypeDocument.getName().buffer,
    });
    _ = z.inputInt2("Cell Size", .{ .v = entityTypeDocument.getCellSize() });
    const gridPosition = entityTypeDocument.getGridPosition().*;
    z.text("Cell: {d:0.0},{d:0.0}", .{ gridPosition[0], gridPosition[1] });
    if (z.button("Set Icon Texture", .{})) {
        if (context.openFileWithDialog(.texture)) |textureDocument| {
            entityTypeDocument.setTextureId(textureDocument.getId());
        }
    }
    textureInput(context, entityTypeDocument);
    drawIconMenu(context, entityTypeDocument);
    // TODO: Icon select cell from texture
}

fn textureInput(context: *Context, entityTypeDocument: *EntityTypeDocument) void {
    const textureId = entityTypeDocument.getTextureId();
    const textureFilePath = (if (textureId) |id| context.getFilePathById(id) else null) orelse "None";
    z.text("{s}", .{textureFilePath});
    if (z.beginDragDropTarget()) {
        if (z.getDragDropPayload()) |payload| {
            const node: *Node = @as(**Node, @ptrCast(@alignCast(payload.data.?))).*;

            switch (node.*) {
                .directory => {},
                .file => |file| {
                    if (file.documentType == .texture) {
                        if (z.acceptDragDropPayload("asset", .{})) |_| {
                            const newTextureId = context.getIdByFilePath(file.path) orelse unreachable;
                            entityTypeDocument.setTextureId(newTextureId);
                        }
                    }
                },
            }
        }
        z.endDragDropTarget();
    }
}

fn drawIconMenu(context: *Context, entityTypeDocument: *EntityTypeDocument) void {
    const textureId = entityTypeDocument.getTextureId() orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;
    const cellSize = entityTypeDocument.getCellSize().*;
    const sourcePosition: @Vector(2, f32) = @floatFromInt(entityTypeDocument.getGridPosition().* * cellSize);
    const source = rl.Rectangle.init(
        sourcePosition[0],
        sourcePosition[1],
        @floatFromInt(cellSize[0]),
        @floatFromInt(cellSize[1]),
    );
    const scaledSize: Vector = cellSize * context.scaleV;
    c.rlImGuiImageRect(@ptrCast(texture), scaledSize[0], scaledSize[1], @bitCast(source));
}

fn handleInput(context: *Context, _: *Editor, entityTypeDocument: *EntityTypeDocument) void {
    utils.cameraControls(context);

    const textureId = entityTypeDocument.getTextureId() orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;
    const cellSize = entityTypeDocument.getCellSize().*;
    if (@reduce(.And, cellSize == Vector{ 0, 0 })) return;
    const gridPosition = utils.getMouseGridPositionWithSize(context, cellSize);

    const textureSize: Vector = .{ texture.width, texture.height };
    const textureGridSize: Vector = @divFloor(textureSize, entityTypeDocument.getCellSize().*);

    const isInBounds = @reduce(.And, gridPosition >= Vector{ 0, 0 }) and @reduce(.And, gridPosition < textureGridSize);

    if (isInBounds) {
        utils.highlightHoveredCell(context, entityTypeDocument.getCellSize().*, textureGridSize);

        if (z.isMouseClicked(.left)) {
            entityTypeDocument.setGridPosition(gridPosition);
        }
    }
}
