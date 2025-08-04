const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c");
const lib = @import("lib");
const config = @import("lib").config;
const LayoutGeneric = lib.LayoutGeneric;
const Context = lib.Context;
const Editor = lib.Editor;
const EntityTypeDocument = lib.documents.EntityTypeDocument;
const Vector = lib.Vector;
const Node = lib.Node;
const DocumentTag = lib.DocumentTag;
const UUID = lib.UUIDSerializable;
const utils = @import("utils.zig");
const propertyEditor = @import("property.zig").propertyEditor;

pub const LayoutEntityType = LayoutGeneric(.entityType, draw, menu, handleInput);

fn draw(context: *Context, entityTypeDocument: *EntityTypeDocument) void {
    const textureId = entityTypeDocument.getTextureId().* orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;
    rl.drawTextureEx(texture.*, .{ .x = 0, .y = 0 }, 0, @floatFromInt(context.scale), rl.Color.white);
}

fn menu(context: *Context, editor: *Editor, entityTypeDocument: *EntityTypeDocument) void {
    const screenSize: @Vector(2, f32) = @floatFromInt(Vector{ rl.getScreenWidth(), rl.getScreenHeight() });
    z.setNextWindowPos(.{ .x = 0, .y = config.editorContentOffset });
    z.setNextWindowSize(.{ .w = 300, .h = screenSize[1] - config.editorContentOffset });
    _ = z.begin("Entity Type Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
        .no_bring_to_front_on_focus = true,
    } });
    defer z.end();

    utils.activeDocumentLabel(context, editor);

    if (z.button("Reset Camera", .{})) {
        utils.resetCamera(context);
    }
    z.text("{d:0.0},{d:0.0}", .{ editor.camera.target.x, editor.camera.target.y });

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
    _ = utils.assetInput(.texture, context, entityTypeDocument.getTextureId());
    drawIconMenu(context, entityTypeDocument);
    propertyEditor(context, .{ .entityType = entityTypeDocument });
}

pub fn drawIconMenu(context: *Context, entityTypeDocument: *EntityTypeDocument) void {
    const textureId = entityTypeDocument.getTextureId().* orelse return;
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

fn handleInput(
    context: *Context,
    editor: *Editor,
    entityTypeDocument: *EntityTypeDocument,
) void {
    utils.cameraControls(&editor.camera);

    const textureId = entityTypeDocument.getTextureId().* orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;
    const cellSize = entityTypeDocument.getCellSize().*;
    if (@reduce(.And, cellSize == Vector{ 0, 0 })) return;
    const gridPosition = utils.getMouseGridPositionWithSize(context, cellSize);

    const textureSize: Vector = .{ texture.width, texture.height };
    const textureGridSize: Vector = @divFloor(textureSize, entityTypeDocument.getCellSize().*);

    const isInBounds = @reduce(.And, gridPosition >= Vector{ 0, 0 }) and @reduce(.And, gridPosition < textureGridSize);

    if (isInBounds) {
        utils.highlightHoveredCell(context, entityTypeDocument.getCellSize().*, textureGridSize, false);

        if (z.isMouseClicked(.left)) {
            entityTypeDocument.setGridPosition(gridPosition);
        }
    }
}
