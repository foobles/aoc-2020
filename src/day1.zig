const std = @import("std");
const file_util = @import("file_util.zig");

const Allocator = std.mem.Allocator;

pub fn findSumProduct2(nums: []const i32, search: i32) ?i32 {
    return outer: for (nums) |n, i| {
        for (nums[i + 1 ..]) |m| {
            if (n + m == search) {
                break :outer n * m;
            }
        }
    } else null;
}

pub fn findSumProduct3(nums: []const i32, search: i32) ?i32 {
    return outer: for (nums) |n, i| {
        for (nums[i + 1 ..]) |m, j| {
            for (nums[i + j + 2 ..]) |k| {
                if (n + m + k == search) {
                    break :outer n * m * k;
                }
            }
        }
    } else null;
}


const Solution = struct {
    prod2: ?i32,
    prod3: ?i32,
};

pub fn solve(alloc: *Allocator) !Solution {
    const data_file = try file_util.getDayFile(alloc, 1, "expense_report.txt");
    defer data_file.close();

    const file_reader = std.io.bufferedReader(data_file.reader()).reader();
    var nums = std.ArrayList(i32).init(alloc);
    defer nums.deinit();

    var buf: [256]u8 = undefined;
    while (try file_util.readLine(file_reader, &buf)) |line| {
        try nums.append(try std.fmt.parseInt(i32, line, 10));
    }

    return Solution {
        .prod2 = findSumProduct2(nums.items, 2020),
        .prod3 = findSumProduct3(nums.items, 2020),
    };
}

const expect = std.testing.expect;

test "findSumProduct2 contains sum" {
    expect(findSumProduct2(&[_]i32{ 5, 6, 7, 20 }, 26) == @as(i32, 120));
}

test "findSumProduct2 single element" {
    expect(findSumProduct2(&[_]i32{1}, 5) == null);
}

test "findSumProduct2 does not contain sum" {
    expect(findSumProduct2(&[_]i32{ 5, 6, 7 }, 14) == null);
}
