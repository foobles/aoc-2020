const std = @import("std");
const file_util = @import("file_util.zig");

const fmt = std.fmt;
const sort = std.sort;
const mem = std.mem;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Solution = struct {
    diff_product: usize,
    arrangements: u64,
};

pub fn solve(alloc: *Allocator) !Solution {
    var jolt_list = ArrayList(usize).init(alloc);
    defer jolt_list.deinit();

    var line_iter = try file_util.dayFileLines(alloc, 10, "adapters.txt");
    defer line_iter.deinit();

    try jolt_list.append(0);
    while (try line_iter.next()) |line| {
        try jolt_list.append(try fmt.parseUnsigned(usize, line, 10));
    }
    sort.sort(usize, jolt_list.items, {}, comptime sort.asc(usize));
    try jolt_list.append(jolt_list.items[jolt_list.items.len - 1] + 3);

    return Solution{
        .diff_product = countJoltDiffProductAssumeSorted(jolt_list.items),
        .arrangements = try countJoltArrangementsAssumeSorted(alloc, jolt_list.items),
    };
}

fn countJoltDiffProductAssumeSorted(jolts: []const usize) usize {
    if (jolts.len == 0)
        return 0;

    var diff_1_count: usize = 0;
    var diff_3_count: usize = 0;
    for (jolts[1..]) |cur, i| {
        const prev = jolts[i];
        const diff = cur - prev;
        if (diff == 1) {
            diff_1_count += 1;
        } else if (diff == 3) {
            diff_3_count += 1;
        }
    }
    return diff_1_count * diff_3_count;
}

fn countJoltArrangementsAssumeSorted(alloc: *Allocator, jolts: []const usize) !u64 {
    if (jolts.len == 0)
        return @as(u64, 1);

    const map = try alloc.alloc(u64, jolts[jolts.len - 1] + 1);
    defer alloc.free(map);
    mem.set(u64, map, 0);

    map[jolts[0]] = 1;
    for (jolts[1..]) |jolt| {
        var cur_count: u64 = 0;
        var i: usize = 1;
        while (i <= 3) : (i += 1) {
            if (jolt < i)
                break;
            cur_count += map[jolt - i];
        }
        map[jolt] = cur_count;
    }
    return map[map.len - 1];
}
