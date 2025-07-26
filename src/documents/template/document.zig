const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;

pub const TemplateData = struct {
    selected: ArrayList(UUID),

    const initialSelectedCapacity = 10;

    pub fn init(allocator: Allocator) TemplateData {
        return TemplateData{
            .selected = ArrayList(UUID).initCapacity(allocator, initialSelectedCapacity) catch unreachable,
        };
    }

    pub fn deinit(self: *TemplateData, allocator: Allocator) void {
        self.selected.clearAndFree(allocator);
    }

    pub fn clone(self: TemplateData, allocator: Allocator) TemplateData {
        var cloned = TemplateData.init(allocator);

        cloned.selected.appendSlice(allocator, self.selected.items) catch unreachable;

        return cloned;
    }
};

pub const TemplateDocument = struct {
    allocator: Allocator,
    template: TemplateData,

    // Put editor state here

    pub fn init(allocator: Allocator) TemplateDocument {
        return TemplateDocument{
            .allocator = allocator,
            .template = undefined,
        };
    }

    pub fn deinit(self: *TemplateDocument) void {
        self.template.deinit(self.allocator);
    }

    pub fn load(self: *TemplateDocument) void {
        // Put loading logic here, any textures that needs loading etc
        // TODO: Provide a resource system that handles loading textures and other assets
        self.template = TemplateData.init(self.allocator);
    }

    pub fn serialize(self: *const TemplateDocument, writer: anytype) !void {
        try std.json.stringify(self.template, .{}, writer);
    }

    pub fn deserialize(allocator: Allocator, reader: anytype) !*TemplateDocument {
        const parsed = try std.json.parseFromTokenSource(TemplateData, allocator, reader, .{});
        const templateData = parsed.value.clone(allocator);
        parsed.deinit();

        var templateDocument = try allocator.create(TemplateDocument);
        templateDocument.* = TemplateDocument.init(allocator);
        templateDocument.template = templateData;
        templateDocument.load();

        return templateDocument;
    }
};
