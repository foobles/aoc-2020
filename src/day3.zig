const std = @import("std");
const file_util = @import("file_util.zig");

const Allocator = std.mem.Allocator;

const Solution = struct {
    trees_hit: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    const map_file = try file_util.getDayFile(alloc, 3, "map.txt");
    defer map_file.close();
    const map_reader = std.io.bufferedReader(map_file.reader()).reader();

    const slope: usize = 3;

    var x: usize = 0;
    var trees_hit: usize = 0;
    var line_buf: [256]u8 = undefined;
    while (try file_util.readLine(map_reader, &line_buf)) |line| {
        if (line[x] == '#') {
            trees_hit += 1;
        }
        x = (x + slope) % line.len;
    }
    return Solution{
        .trees_hit = trees_hit,
    };
}
