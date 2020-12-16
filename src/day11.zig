const std = @import("std");
const file_util = @import("file_util.zig");

const mem = std.mem;

const Allocator = std.mem.Allocator;

pub const Solution = struct {
    final_seats_occupied: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    var grid = try Grid.init(alloc, 5, 6);
    defer grid.deinit(alloc);

    return Solution{
        .final_seats_occupied = 0,
    };
}

const Grid = struct {
    width: usize,
    height: usize,
    data: []Tile,

    const Tile = union(enum) {
        Chair: struct { occupied: bool },
        Empty: void,
    };

    fn init(alloc: *Allocator, width: usize, height: usize) !Grid {
        return Grid{
            .width = width,
            .height = height,
            .data = try alloc.alloc(Tile, width * height),
        };
    }

    fn deinit(self: Grid, alloc: *Allocator) void {
        alloc.free(self.data);
    }

    fn isInBounds(self: Grid, x: usize, y: usize) bool {
        return (x < self.width and y < self.height);
    }

    fn index(self: Grid, x: usize, y: usize) *Tile {
        return &self.data[x + y * self.width];
    }

    fn indexOccupants(self: Grid, x: usize, y: usize) usize {
        if (!self.isInBounds(x, y))
            return 0;

        return switch (self.index(x, y).*) {
            .Chair => |c| @boolToInt(c.occupied),
            .Empty => 0,
        };
    }

    fn indexOccupantsAtOffset(
        self: Grid,
        x: usize,
        y: usize,
        dx: isize,
        dy: isize,
    ) usize {
        const real_x = offsetUsize(x, dx) orelse return 0;
        const real_y = offsetUsize(y, dy) orelse return 0;
        return self.indexOccupants(real_x, real_y);
    }

    fn countNeighbors(self: Grid, x: usize, y: usize) usize {
        const c = Grid.indexOccupantsAtOffset;
        return c(self, x, y, -1, -1) +
            c(self, x, y, 0, -1) +
            c(self, x, y, 1, -1) +
            c(self, x, y, -1, 0) +
            c(self, x, y, 1, 0) +
            c(self, x, y, -1, 1) +
            c(self, x, y, 0, 1) +
            c(self, x, y, 1, 1);
    }
};

fn offsetUsize(x: usize, offset: isize) ?usize {
    if (offset >= 0) {
        return x + @intCast(usize, offset);
    } else {
        const pos_offset = std.math.absCast(offset);
        if (pos_offset > x)
            return null;
        return x - pos_offset;
    }
}
