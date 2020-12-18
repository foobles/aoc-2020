const std = @import("std");
const file_util = @import("file_util.zig");

const mem = std.mem;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Solution = struct {
    final_seats_occupied: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    var lines = try file_util.dayFileLines(alloc, 11, "layout.txt");
    defer lines.deinit();

    var tiles = ArrayList(Grid.Tile).init(alloc);
    defer tiles.deinit();

    var height: usize = 0;
    var width: usize = undefined;
    while (try lines.next()) |line| {
        if (height == 0) {
            width = line.len;
        } else if (line.len != width) {
            return error.InconsistentWidth;
        }

        for (line) |c| {
            try tiles.append(switch (c) {
                '.' => .Empty,
                'L' => .{ .Chair = .{ .occupied = false } },
                else => return error.InvalidMapTile,
            });
        }

        height += 1;
    }

    if (height == 0)
        return error.NoLines;

    const other_buf = try alloc.alloc(Grid.Tile, width * height);
    defer alloc.free(other_buf);

    var grid = Grid{
        .width = width,
        .height = height,
        .data = tiles.items,
    };

    var buf_double = other_buf;
    while (grid.step(&buf_double, .{
        .count_neighbors = Grid.countVisibleNeighbors,
        .leave_chair_threshold = 5,
    })) {}

    return Solution{
        .final_seats_occupied = grid.countOccupied(),
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

    fn countAdjacentNeighbors(self: Grid, x: usize, y: usize) usize {
        var ret: usize = 0;
        inline for (moore) |offset| {
            ret += self.indexOccupantsAtOffset(x, y, offset.x, offset.y);
        }
        return ret;
    }

    fn countVisibleNeighbors(self: Grid, x: usize, y: usize) usize {
        var ret: usize = 0;
        inline for (moore) |offset| {
            ret += self.occupantVisibleRay(x, y, offset.x, offset.y);
        }
        return ret;
    }

    fn occupantVisibleRay(self: Grid, x: usize, y: usize, dx: isize, dy: isize) usize {
        var cur_x = x;
        var cur_y = y;

        while (true) {
            cur_x = offsetUsize(cur_x, dx) orelse return 0;
            cur_y = offsetUsize(cur_y, dy) orelse return 0;
            if (!self.isInBounds(cur_x, cur_y))
                return 0;

            switch (self.index(cur_x, cur_y).*) {
                .Chair => |c| return @boolToInt(c.occupied),
                .Empty => {},
            }
        }
    }

    fn countOccupied(self: Grid) usize {
        var ret: usize = 0;
        for (self.data) |tile| {
            switch (tile) {
                .Chair => |c| if (c.occupied) {
                    ret += 1;
                },
                else => {},
            }
        }
        return ret;
    }

    fn idxToCoords(self: Grid, idx: usize) UVec2 {
        return .{
            .x = idx % self.width,
            .y = idx / self.width,
        };
    }

    fn step(self: *Grid, other_buf: *[]Tile, comptime strat: StepStrat) bool {
        var changed = false;
        for (self.data) |tile, i| {
            other_buf.*[i] = switch (tile) {
                .Empty => .Empty,
                .Chair => |c| blk: {
                    const coords = self.idxToCoords(i);
                    const neighbors = strat.count_neighbors(self.*, coords.x, coords.y);
                    const new_chair = Tile{
                        .Chair = .{
                            .occupied = if (c.occupied)
                                neighbors < strat.leave_chair_threshold
                            else
                                neighbors == 0,
                        },
                    };
                    if (new_chair.Chair.occupied != c.occupied)
                        changed = true;
                    break :blk new_chair;
                },
            };
        }
        mem.swap([]Tile, &self.data, other_buf);
        return changed;
    }

    const StepStrat = struct {
        count_neighbors: fn (Grid, usize, usize) usize,
        leave_chair_threshold: usize,
    };
};

// zig fmt: off
const moore = [_]IVec2{
    .{ .x = -1, .y = -1 },
    .{ .x =  0, .y = -1 },
    .{ .x =  1, .y = -1 },
    .{ .x = -1, .y =  0 },
    .{ .x =  1, .y =  0 },
    .{ .x = -1, .y =  1 },
    .{ .x =  0, .y =  1 },
    .{ .x =  1, .y =  1 },
};
// zig fmt: on

const IVec2 = struct { x: isize, y: isize };
const UVec2 = struct { x: usize, y: usize };

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
