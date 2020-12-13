const std = @import("std");
const file_util = @import("file_util.zig");

const fmt = std.fmt;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

pub const Solution = struct {
    not_sum: u64,
    weakness: u64,
};

pub fn solve(alloc: *Allocator) !Solution {
    const sum_len = 25;

    const stream_data = try getStreamData(alloc);
    defer alloc.free(stream_data);

    var window: [sum_len]u64 = undefined;
    var sum_map = AutoHashMap(u64, usize).init(alloc);
    defer sum_map.deinit();

    for (window) |*val, i| {
        val.* = stream_data[i];
        for (window[0..i]) |prev_val| {
            const entry = try sum_map.getOrPutValue(val.* + prev_val, 0);
            entry.value += 1;
        }
    }

    var cur_idx: usize = 0;
    const not_sum = for (stream_data[sum_len..]) |num| {
        if (try findNotSumStep(&sum_map, &window, cur_idx, num)) |found|
            break found;
        window[cur_idx] = num;
        cur_idx = (cur_idx + 1) % window.len;
    } else unreachable;

    return Solution{
        .not_sum = not_sum,
        .weakness = findWeakness(stream_data, not_sum).?,
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

fn findWeakness(stream: []const u64, invalid: u64) ?u64 {
    const range = findWeaknessRange(stream, invalid) orelse return null;
    var min = range[0];
    var max = range[0];
    for (range[1..]) |n| {
        if (n < min) 
            min = n;
        if (n > max) 
            max = n;
    }
    return min + max;
} 

fn findWeaknessRange(stream: []const u64, invalid: u64) ?[]const u64 {
    var low: usize = 0;
    var high: usize = 1;

    var cur_sum: u64 = stream[low] + stream[high];
    while (cur_sum != invalid) {
        if (cur_sum > invalid) {
            cur_sum -= stream[low];
            low += 1;
        }
        if (cur_sum < invalid or low == high) {
            high += 1;
            if (high == stream.len)
                return null;
            cur_sum += stream[high];
        } 
    }
    return stream[low..high+1];
}

fn getStreamData(alloc: *Allocator) ![]const u64 {
    var arr = ArrayList(u64).init(alloc);

    var lines = try file_util.dayFileLines(alloc, 9, "stream.txt");
    defer lines.deinit();
    while (try lines.next()) |line| {
        try arr.append(try fmt.parseUnsigned(u64, line, 10));
    }
    return arr.toOwnedSlice();
}