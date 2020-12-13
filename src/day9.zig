const std = @import("std");
const file_util = @import("file_util.zig");

const fmt = std.fmt;

const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;

pub const Solution = struct {
    not_sum: u64,
};

pub fn solve(alloc: *Allocator) !Solution {
    const sum_len = 25;

    var sum_map = AutoHashMap(u64, usize).init(alloc);
    defer sum_map.deinit();

    var window: [sum_len]u64 = undefined;
    var cur_idx: usize = 0;

    var lines = try file_util.dayFileLines(alloc, 9, "stream.txt");
    defer lines.deinit();
    for (window) |*val, i| {
        const next = (try lines.next()) orelse return error.NoValue;
        val.* = try fmt.parseInt(u64, next, 10);
        for (window[0..i]) |prev_val| {
            const entry = try sum_map.getOrPutValue(val.* + prev_val, 0);
            entry.value += 1;
        }
    }

    const not_sum = while (try lines.next()) |line| {
        const num = try fmt.parseInt(u64, line, 10);
        if (try findNotSumStep(&sum_map, &window, cur_idx, num)) |found|
            break found;
        window[cur_idx] = num;
        cur_idx = (cur_idx + 1) % window.len;
    } else null;

    return Solution{
        .not_sum = not_sum.?,
    };
}

fn findNotSumStep(
    sum_map: *AutoHashMap(u64, usize),
    window: []const u64,
    cur_idx: usize,
    num: u64,
) !?u64 {
    if (!sum_map.contains(num))
        return num;

    for (window) |other, i| {
        if (i != cur_idx) {
            const entry = try sum_map.getOrPutValue(other + num, 0);
            entry.value += 1;
        }
    }

    const old_num = window[cur_idx];
    for (window) |other, i| {
        if (i != cur_idx) {
            const sum = other + old_num;
            const count_entry = sum_map.getEntry(sum).?;
            if (count_entry.value > 1) {
                count_entry.value -= 1;
            } else {
                sum_map.removeAssertDiscard(sum);
            }
        }
    }
    return null;
}
