const std = @import("std");
const file_util = @import("file_util.zig");
const mem = std.mem;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Solution = struct {
    trees_hit_1: usize,
    trees_hit_product: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    const map_file = try file_util.getDayFile(alloc, 3, "map.txt");
    defer map_file.close();
    const map_reader = std.io.bufferedReader(map_file.reader()).reader();
    const map_bytes = try map_reader.readAllAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(map_bytes);

    var grid = ArrayList([]const u8).init(alloc);
    defer grid.deinit();

    var lines_iter = mem.split(map_bytes, "\n");
    while (lines_iter.next()) |line| {
        try grid.append(mem.trim(u8, line, &std.ascii.spaces));
    }

    const items = grid.items;
    return Solution{
        .trees_hit_1 = slopeTreesHit(.{ .x = 3, .y = 1 }, items),
        .trees_hit_product = slopeTreesHit(.{ .x = 1, .y = 1 }, items) *
            slopeTreesHit(.{ .x = 3, .y = 1 }, items) *
            slopeTreesHit(.{ .x = 5, .y = 1 }, items) *
            slopeTreesHit(.{ .x = 7, .y = 1 }, items) *
            slopeTreesHit(.{ .x = 1, .y = 2 }, items),
    };
}

fn slopeTreesHit(slope: UVec2, map: []const []const u8) usize {
    var trees_hit: usize = 0;
    var cur_pos = UVec2{ .x = 0, .y = 0 };
    while (cur_pos.y < map.len) {
        const line = map[cur_pos.y];
        if (line[cur_pos.x] == '#') {
            trees_hit += 1;
        }

        cur_pos.x = (cur_pos.x + slope.x) % line.len;
        cur_pos.y += slope.y;
    }
    return trees_hit;
}

const UVec2 = struct {
    x: usize,
    y: usize,
};

const expectEqual = std.testing.expectEqual;

test "count trees hit" {
    const map = [_][]const u8{
        "..##.......",
        "#...#...#..",
        ".#....#..#.",
        "..#.#...#.#",
        ".#...##..#.",
        "..#.##.....",
        ".#.#.#....#",
        ".#........#",
        "#.##...#...",
        "#...##....#",
        ".#..#...#.#",
    };
    expectEqual(slopeTreesHit(.{ .x = 3, .y = 1 }, &map), 7);
}

test "count trees hit big y jump" {
    const map = [_][]const u8{
        "..##.......",
        "#...#...#..",
        ".#....#..#.",
        "..#.#...#.#",
        ".#...##..#.",
        "..#.##.....",
        ".#.#.#....#",
        ".#........#",
        "#.##...#...",
        "#...##....#",
        ".#..#...#.#",
    };
    expectEqual(slopeTreesHit(.{ .x = 3, .y = 15 }, &map), 0);
}

test "count trees hit big x jump" {
    const map = [_][]const u8{
        "..##.......",
        "#...#...#..",
        ".#....#..#.",
        "..#.#...#.#",
        ".#...##..#.",
        "..#.##.....",
        ".#.#.#....#",
        ".#........#",
        "#.##...#...",
        "#...##....#",
        ".#..#...#.#",
    };
    expectEqual(slopeTreesHit(.{ .x = 14, .y = 1 }, &map), 7);
}