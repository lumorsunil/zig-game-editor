const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Vector = @import("vector.zig").Vector;
const Rectangle = @import("rectangle.zig").Rectangle;

pub const SelectGrid = struct {
    size: Vector,
    offset: Vector,
    selected: []u1,

    pub fn init() SelectGrid {
        return SelectGrid{
            .size = .{ 0, 0 },
            .offset = .{ 0, 0 },
            .selected = &.{},
        };
    }

    pub fn initPoint(allocator: Allocator, point: Vector) SelectGrid {
        return SelectGrid{
            .size = .{ 1, 1 },
            .offset = point,
            .selected = brk: {
                const selected = allocSelected(allocator, .{ 1, 1 });
                selected[0] = 1;
                break :brk selected;
            },
        };
    }

    pub fn initOwned(size: Vector, offset: Vector, selected: []u1) SelectGrid {
        return SelectGrid{
            .size = size,
            .offset = offset,
            .selected = selected,
        };
    }

    pub fn deinit(self: *SelectGrid, allocator: Allocator) void {
        if (self.selected.len > 0) {
            allocator.free(self.selected);
            self.selected = &.{};
        }
    }

    pub fn clone(self: SelectGrid, allocator: Allocator) SelectGrid {
        return SelectGrid{
            .size = self.size,
            .offset = self.offset,
            .selected = allocator.dupe(u1, self.selected) catch unreachable,
        };
    }

    pub fn clear(self: *SelectGrid, allocator: Allocator) void {
        self.deinit(allocator);
        self.* = init();
    }

    pub fn getMax(self: SelectGrid) Vector {
        return self.offset + self.size - @as(Vector, @splat(1));
    }

    pub fn allocSelected(allocator: Allocator, size: Vector) []u1 {
        const n: usize = @intCast(@reduce(.Mul, size));
        return allocator.alloc(u1, n) catch unreachable;
    }

    pub fn getIndex(self: SelectGrid, relative: Vector) usize {
        std.debug.assert(@reduce(.And, relative < self.size));
        std.debug.assert(@reduce(.And, relative >= @as(Vector, @splat(0))));
        const i = relative[0] + relative[1] * self.size[0];
        defer std.debug.assert(i >= 0);
        defer if (i >= self.selected.len) {
            std.log.err("index out of bounds: arr[{d}], len={d}, relative={d}", .{ i, self.selected.len, relative });
            std.debug.assert(i < self.selected.len);
        };
        return @intCast(i);
    }

    pub fn getIndexAbsolute(self: SelectGrid, absolute: Vector) usize {
        const relative = absolute - self.offset;
        return self.getIndex(relative);
    }

    pub fn selectPoint(self: *SelectGrid, allocator: Allocator, absolute: Vector) void {
        self.setPoint(allocator, absolute, 1);
    }

    pub fn deselectPoint(self: *SelectGrid, allocator: Allocator, absolute: Vector) void {
        self.setPoint(allocator, absolute, 0);
    }

    pub fn togglePoint(self: *SelectGrid, allocator: Allocator, absolute: Vector) void {
        const value: u1 = if (self.isSelected(absolute)) 0 else 1;
        self.setPoint(allocator, absolute, value);
    }

    pub fn selectRegion(self: *SelectGrid, allocator: Allocator, min: Vector, max: Vector) void {
        self.setAll(allocator, min, max, 1);
    }

    pub fn deselectRegion(self: *SelectGrid, allocator: Allocator, min: Vector, max: Vector) void {
        self.setAll(allocator, min, max, 0);
    }

    pub fn setPoint(self: *SelectGrid, allocator: Allocator, absolute: Vector, value: u1) void {
        if (value == 0) {
            if (!self.isPointInside(absolute)) {
                return;
            } else {
                return self.setPointVolatile(absolute, value);
                // Candidate for shrinking grid
            }
        } else if (self.isPointInside(absolute)) {
            return self.setPointVolatile(absolute, value);
        } else {
            var otherGrid = initPoint(allocator, absolute);
            defer otherGrid.deinit(allocator);
            self.setOr(allocator, otherGrid);
        }
    }

    pub fn setPointRelative(self: SelectGrid, relative: Vector, value: u1) void {
        std.debug.assert(self.isPointInside(self.offset + relative));
        self.selected[self.getIndex(relative)] = value;
    }

    fn setPointVolatile(self: SelectGrid, absolute: Vector, value: u1) void {
        const rel = absolute - self.offset;
        self.setPointRelative(rel, value);
    }

    pub fn isPointInside(self: SelectGrid, absolute: Vector) bool {
        return self.selected.len > 0 and @reduce(.And, absolute >= self.offset) and @reduce(.And, absolute <= self.getMax());
    }

    pub fn isGridBoundsInside(self: SelectGrid, grid: SelectGrid) bool {
        return self.isGridBoundsInsideMinMax(grid.offset, grid.getMax());
    }

    pub fn isGridBoundsInsideMinMax(self: SelectGrid, min: Vector, max: Vector) bool {
        return @reduce(.And, min >= self.offset) and @reduce(.And, max <= self.getMax());
    }

    pub fn setOr(self: *SelectGrid, allocator: Allocator, source: SelectGrid) void {
        self.ensureContains(allocator, source);
        self.setOrVolatile(source);
    }

    fn setOrVolatile(self: *SelectGrid, source: SelectGrid) void {
        const size: @Vector(2, usize) = @intCast(source.size);

        for (0..size[0]) |x| {
            for (0..size[1]) |y| {
                const sourceRel: Vector = @intCast(@Vector(2, usize){ x, y });
                const absolute = source.offset + sourceRel;
                const selfIndex = self.getIndexAbsolute(absolute);
                const sourceIndex = source.getIndexAbsolute(absolute);
                self.selected[selfIndex] |= source.selected[sourceIndex];
            }
        }
    }

    pub fn setAll(
        self: *SelectGrid,
        allocator: Allocator,
        min: Vector,
        max: Vector,
        value: u1,
    ) void {
        if (value == 0) {
            if (!self.isPointInside(min) and !self.isPointInside(max)) {
                return;
            }

            const clampedMin = @max(self.offset, min);
            const clampedMax = @min(self.getMax(), max);
            const size: @Vector(2, usize) = @intCast(clampedMax - clampedMin + Vector{ 1, 1 });

            for (0..size[0]) |x| {
                for (0..size[1]) |y| {
                    const sourceRel: Vector = @intCast(@Vector(2, usize){ x, y });
                    const absolute = clampedMin + sourceRel;
                    const i = self.getIndexAbsolute(absolute);
                    self.selected[i] = value;
                }
            }

            // Candidate for shrinking grid
        } else {
            self.ensureContainsMinMax(allocator, min, max);
            const rectSize: @Vector(2, usize) = @intCast((max - min) + Vector{ 1, 1 });

            for (0..rectSize[0]) |x| {
                for (0..rectSize[1]) |y| {
                    const relative: Vector = @intCast(@Vector(2, usize){ x, y });
                    const absolute = relative + min;
                    const i = self.getIndexAbsolute(absolute);
                    self.selected[i] = value;
                }
            }
        }
    }

    pub fn ensureContains(self: *SelectGrid, allocator: Allocator, other: SelectGrid) void {
        self.ensureContainsMinMax(allocator, other.offset, other.getMax());
        std.debug.assert(self.isGridBoundsInside(other));
    }

    pub fn ensureContainsMinMax(
        self: *SelectGrid,
        allocator: Allocator,
        min: Vector,
        max: Vector,
    ) void {
        const newMin = @min(self.offset, min);
        const newMax = @max(self.getMax(), max);
        const newSize = newMax - newMin + Vector{ 1, 1 };

        if (@reduce(.Or, newMin < self.offset) or @reduce(.Or, newSize > self.size)) {
            var newSelectGrid = initOwned(newSize, newMin, allocSelected(allocator, newSize));
            @memset(newSelectGrid.selected, 0);
            newSelectGrid.setOrVolatile(self.*);
            self.deinit(allocator);
            self.* = newSelectGrid;
        }

        std.debug.assert(self.isGridBoundsInsideMinMax(min, max));
    }

    pub fn hasSelected(self: SelectGrid) bool {
        return std.mem.indexOfScalar(u1, self.selected, 1) != null;
    }

    /// Caller owns return pointer
    pub fn getSelected(self: SelectGrid, allocator: Allocator) []Vector {
        var result = std.ArrayList(Vector).init(allocator);
        const size: @Vector(2, usize) = @intCast(self.size);

        for (0..size[0]) |x| {
            for (0..size[1]) |y| {
                const relative: Vector = @intCast(@Vector(2, usize){ x, y });
                const absolute = relative + self.offset;
                const i = self.getIndex(relative);
                const value = self.selected[i];

                if (value == 1) result.append(absolute) catch unreachable;
            }
        }

        return result.toOwnedSlice() catch unreachable;
    }

    pub fn isSelected(self: SelectGrid, absolute: Vector) bool {
        if (self.isPointInside(absolute)) {
            return self.selected[self.getIndexAbsolute(absolute)] == 1;
        } else {
            return false;
        }
    }

    pub fn lineIterator(self: SelectGrid) LineIterator {
        return LineIterator.init(self);
    }

    pub const LineIterator = struct {
        cursor: ?Vector = null,
        innerIterator: ?InnerLineIterator = null,
        selectGrid: SelectGrid,

        pub fn init(selectGrid: SelectGrid) LineIterator {
            return LineIterator{
                .selectGrid = selectGrid,
            };
        }

        pub fn next(self: *LineIterator) ?Line {
            if (self.innerIterator) |*it| if (it.next()) |line| return line;

            while (true) {
                self.incCursor();
                self.cursor = self.findNextStart() orelse return null;
                self.innerIterator = InnerLineIterator.init(self.selectGrid, self.cursor.?);

                if (self.innerIterator.?.next()) |line| return line;
            }
        }

        fn incCursor(self: *LineIterator) void {
            if (self.cursor == null) {
                self.cursor = Vector{ 0, 0 };
                return;
            }

            const sizeX = self.selectGrid.size[0];

            if (self.cursor.?[0] == sizeX - 1) {
                self.cursor = Vector{ 0, self.cursor.?[1] + 1 };
            } else {
                self.cursor.? += Vector{ 1, 0 };
            }
        }

        fn findNextStart(self: *LineIterator) ?Vector {
            const min: @Vector(2, usize) = @intCast(self.cursor orelse Vector{ 0, 0 });
            const max: @Vector(2, usize) = @intCast(self.selectGrid.size);
            var minX, const minY = min;
            const maxX, const maxY = max;

            for (minY..maxY) |y| {
                for (minX..maxX) |x| {
                    const v: Vector = @intCast(@Vector(2, usize){ x, y });
                    if (self.selectGrid.isSelected(v + self.selectGrid.offset)) {
                        return v;
                    }
                }
                minX = 0;
            }

            return null;
        }
    };

    pub const Line = struct {
        position: Vector,
        cover: Cover,

        pub fn init(position: Vector, cover: Cover) Line {
            return Line{
                .position = position,
                .cover = cover,
            };
        }

        pub fn lineCoordinates(self: Line) struct { min: Vector, max: Vector } {
            return switch (self.cover) {
                .right => .{
                    .min = self.position + Vector{ 1, 0 },
                    .max = self.position + Vector{ 1, 1 },
                },
                .up => .{
                    .min = self.position + Vector{ 0, 0 },
                    .max = self.position + Vector{ 1, 0 },
                },
                .left => .{
                    .min = self.position + Vector{ 0, 0 },
                    .max = self.position + Vector{ 0, 1 },
                },
                .down => .{
                    .min = self.position + Vector{ 0, 1 },
                    .max = self.position + Vector{ 1, 1 },
                },
            };
        }

        pub const Cover = enum {
            right,
            up,
            left,
            down,

            pub fn toAdjacentCoordinate(self: Cover) Vector {
                return switch (self) {
                    .right => .{ 1, 0 },
                    .up => .{ 0, -1 },
                    .left => .{ -1, 0 },
                    .down => .{ 0, 1 },
                };
            }
        };
    };

    const InnerLineIterator = struct {
        cursor: Vector,
        selectGrid: SelectGrid,
        coveredLines: struct {
            current: ?Line.Cover = null,

            pub fn next(self: *@This()) ?Line.Cover {
                const nextCover: ?Line.Cover = if (self.current == null)
                    .right
                else switch (self.current.?) {
                    .right => .up,
                    .up => .left,
                    .left => .down,
                    else => null,
                };

                self.current = nextCover;
                return self.current;
            }
        } = .{},

        pub fn init(selectGrid: SelectGrid, cursor: Vector) InnerLineIterator {
            return InnerLineIterator{
                .cursor = cursor,
                .selectGrid = selectGrid,
            };
        }

        pub fn next(self: *InnerLineIterator) ?Line {
            const cover = self.coveredLines.next() orelse return null;
            const adjacentPosition = cover.toAdjacentCoordinate() + self.cursor + self.selectGrid.offset;

            if (self.selectGrid.isSelected(adjacentPosition)) {
                return self.next();
            } else {
                return Line.init(self.cursor, cover);
            }
        }
    };
};
