const std = @import("std");
const z = @import("zgui");
const lib = @import("lib");
const Context = lib.Context;
const PropertyObject = lib.properties.PropertyObject;
const PropertyArray = lib.properties.PropertyArray;
const Property = lib.properties.Property;
const PropertyFloat = lib.properties.PropertyFloat;
const PropertyInteger = lib.properties.PropertyInteger;
const PropertyString = lib.properties.PropertyString;
const PropertyBoolean = lib.properties.PropertyBoolean;
const PropertyAssetReference = lib.properties.PropertyAssetReference;
const PropertyEntityReference = lib.properties.PropertyEntityReference;
const EntityTypeDocument = lib.documents.EntityTypeDocument;
const SceneEntityCustom = lib.scene.SceneEntityCustom;
const SceneDocument = lib.documents.SceneDocument;
const utils = @import("utils.zig");

const PropertyEditorMode = union(enum) {
    entityType: *EntityTypeDocument,
    entityInstance: *SceneEntityCustom,

    pub fn getProperties(self: PropertyEditorMode) *PropertyObject {
        return switch (self) {
            .entityType => |entityTypeDocument| entityTypeDocument.getProperties(),
            .entityInstance => |custom| &custom.properties,
        };
    }

    pub fn canEditPropertySchema(self: PropertyEditorMode) bool {
        return self == .entityType;
    }

    pub fn canEditEntityReference(self: PropertyEditorMode) bool {
        return self == .entityInstance;
    }
};

pub fn propertyEditor(context: *Context, editorMode: PropertyEditorMode) void {
    z.separatorText("Properties");
    if (z.treeNodeFlags("Properties", .{ .default_open = true, .framed = true, .open_on_arrow = true })) {
        defer z.treePop();

        objectPropertyEditor(context, editorMode, editorMode.getProperties());
    }
}

fn dynamicPropertyEditor(
    context: *Context,
    editorMode: PropertyEditorMode,
    property: *Property,
) void {
    switch (property.property) {
        .object => |*object| objectPropertyEditor(context, editorMode, object),
        .array => |*array| arrayPropertyEditor(context, editorMode, array),
        .float => |*float| floatPropertyEditor(float),
        .integer => |*integer| integerPropertyEditor(integer),
        .string => |*string| stringPropertyEditor(string),
        .boolean => |*string| booleanPropertyEditor(string),
        .assetReference => |*assetReference| assetReferencePropertyEditor(context, editorMode, assetReference),
        .entityReference => |*entityReference| entityReferencePropertyEditor(context, editorMode, entityReference),
        //else => |e| std.debug.panic("property type {s} not supported in the editor", .{@tagName(e)}),
    }
}

fn objectPropertyEditor(
    context: *Context,
    editorMode: PropertyEditorMode,
    object: *PropertyObject,
) void {
    if (editorMode.canEditPropertySchema()) {
        if (z.button("+", .{ .w = 24, .h = 24 })) {
            object.addNewProperty(context.allocator);
        }
    }

    var it = object.iterator();
    var propertyToDelete: ?PropertyObject.K = null;

    while (it.next()) |property| {
        const key = property.key_ptr;
        const value = property.value_ptr;

        if (z.treeNode(&value.id.serializeZ())) {
            defer z.treePop();
            if (editorMode.canEditPropertySchema()) {
                if (z.button("Delete Property", .{})) {
                    propertyToDelete = key.*;
                }
                _ = z.inputText("Key", .{
                    .buf = key.buffer,
                });
            } else {
                z.text("Key: {f}", .{key.*});
            }
            if (editorMode.canEditPropertySchema()) {
                var propertyType = std.meta.activeTag(value.property);
                if (z.comboFromEnum("Type", &propertyType)) {
                    value.setType(context.allocator, propertyType);
                }
            } else {
                z.text("Type: {s}", .{@tagName(value.property)});
            }
            dynamicPropertyEditor(context, editorMode, value);
        }
    }

    if (propertyToDelete) |key| {
        object.deleteProperty(context.allocator, key);
    }
}

fn arrayPropertyEditor(
    context: *Context,
    editorMode: PropertyEditorMode,
    array: *PropertyArray,
) void {
    if (z.button("+", .{ .w = 24, .h = 24 })) {
        array.addNewItem(context.allocator);
    }

    if (editorMode.canEditPropertySchema()) {
        var propertyType = array.subType;
        if (z.comboFromEnum("Sub Type", &propertyType)) {
            array.setSubType(context.allocator, propertyType);
        }
    } else {
        z.text("Sub Type: {s}", .{@tagName(array.subType)});
    }

    var itemToDelete: ?usize = null;

    for (array.items.items, 0..) |*item, i| {
        if (z.treeNode(&item.id.serializeZ())) {
            defer z.treePop();
            if (editorMode.canEditPropertySchema()) {
                if (z.button("Delete Item", .{})) {
                    itemToDelete = i;
                }
            }
            dynamicPropertyEditor(context, editorMode, item);
        }
    }

    if (itemToDelete) |i| {
        array.deleteItem(context.allocator, i);
    }
}

fn floatPropertyEditor(float: *PropertyFloat) void {
    _ = z.inputFloat("Value", .{
        .v = &float.value,
    });
}

fn integerPropertyEditor(integer: *PropertyInteger) void {
    _ = z.inputInt("Value", .{
        .v = &integer.value,
    });
}

fn stringPropertyEditor(string: *PropertyString) void {
    _ = z.inputText("Value", .{
        .buf = string.value.buffer,
    });
}

fn booleanPropertyEditor(boolean: *PropertyBoolean) void {
    _ = z.checkbox("Value", .{
        .v = &boolean.value,
    });
}

fn assetReferencePropertyEditor(
    context: *Context,
    editorMode: PropertyEditorMode,
    assetReference: *PropertyAssetReference,
) void {
    if (editorMode.canEditPropertySchema()) {
        if (z.comboFromEnum("Asset Type", &assetReference.assetType)) {
            assetReference.assetId = null;
        }
    } else {
        z.text("Asset Type: {s}", .{@tagName(assetReference.assetType)});
    }

    switch (assetReference.assetType) {
        inline else => |t| {
            _ = utils.assetInput(t, context, &assetReference.assetId);
        },
    }
}

fn entityReferencePropertyEditor(
    context: *Context,
    editorMode: PropertyEditorMode,
    entityReference: *PropertyEntityReference,
) void {
    if (editorMode.canEditEntityReference()) {
        z.text("Scene: {?f}", .{entityReference.sceneId});
        z.text("Entity: {?f}", .{entityReference.entityId});
        if (z.button("Set Entity", .{})) {
            if (context.getCurrentEditor()) |editor| {
                switch (editor.document.content.?) {
                    .scene => |*sceneDocument| sceneDocument.openSetEntityWindow(
                        &entityReference.sceneId,
                        &entityReference.entityId,
                    ),
                    else => {},
                }
            }
        }
    }
}
