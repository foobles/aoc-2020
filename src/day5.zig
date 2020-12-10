const std = @import("std");
const file_util = @import("file_util.zig");

const Allocator = std.mem.Allocator;
const PackedIntArray = std.PackedIntArray;

pub const Solution = struct {
    highest_seat: u16,
    my_seat: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    var seat_lines = try file_util.dayFileLines(alloc, 5, "seats.txt");
    defer seat_lines.deinit();

    var highest: u16 = 0;
    var filled_seats = PackedIntArray(u1, 1024).init(std.mem.zeroes([1024]u1));
    while (try seat_lines.next()) |line| {
        var cur: u16 = 0;
        for (line) |c, i| {
            if (c == 'B' or c == 'R') {
                cur |= (@as(u16, 1) << @intCast(u4, line.len - i - 1));
            }
        }
        filled_seats.set(cur, 1);
        if (cur > highest)
            highest = cur;
    }

    var i: usize = 1;
    const my_seat = while (i < filled_seats.len()) : (i += 1) {
        if (filled_seats.get(i - 1) == 1 and filled_seats.get(i) == 0) {
            break i;
        }
    } else return error.NoSolution;

    return Solution{ .highest_seat = highest, .my_seat = my_seat };
}
