const Vector = @import("vector.zig").Vector;

pub const Rectangle = struct {
    min: Vector,
    max: Vector,

    pub fn init() Rectangle {
        return Rectangle{
            .min = .{ 0, 0 },
            .max = .{ 0, 0 },
        };
    }

    pub fn setPosition(self: *Rectangle, position: Vector) void {
        const _size = self.size();
        self.min = position;
        self.max = self.min + _size;
    }

    pub fn size(self: Rectangle) Vector {
        return (self.max - self.min) + Vector{ 1, 1 };
    }
};
