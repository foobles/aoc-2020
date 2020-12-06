const std = @import("std");
const file_util = @import("file_util.zig");

const Allocator = std.mem.Allocator;
const PackedIntArray = std.PackedIntArray;

pub const Solution = struct {
    highest_seat: u16,
    my_seat: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    const seat_file = try file_util.getDayFile(alloc, 5, "seats.txt");
    defer seat_file.close();
    const file_reader = std.io.bufferedReader(seat_file.reader()).reader();

    var highest: u16 = 0;
    var filled_seats = PackedIntArray(u1, 1024).init(std.mem.zeroes([1024]u1));
    var line_buf: [256]u8 = undefined;
    while (try file_util.readLine(file_reader, &line_buf)) |line| {
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
