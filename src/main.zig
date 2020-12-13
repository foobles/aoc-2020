const std = @import("std");
const fs = std.fs;
const io = std.io;
const fmt = std.fmt;
const meta = std.meta;

const file_util = @import("file_util.zig");

const days = [_]type{
    @import("day1.zig"),
    @import("day2.zig"),
    @import("day3.zig"),
    @import("day4.zig"),
    @import("day5.zig"),
    @import("day6.zig"),
    @import("day7.zig"),
    @import("day8.zig"),
    @import("day9.zig"),
};

pub fn dumpSolutions(alloc: *std.mem.Allocator) !void {
    const stdout = io.getStdOut().writer();
    inline for (days) |day, i| {
        try stdout.print("Day {}:\n", .{i + 1});
        const solution = try day.solve(alloc);
        inline for (meta.fields(@TypeOf(solution))) |field| {
            try stdout.print("\t{} = {}\n", .{
                field.name,
                @field(solution, field.name),
            });
        }
    }
}

pub fn main() anyerror!void {
    var defaultAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = defaultAllocator.deinit();
    const alloc = &defaultAllocator.allocator;
    try dumpSolutions(alloc);
}

test "all days" {
    inline for (days) |day| {
        _ = day;
    }
}
