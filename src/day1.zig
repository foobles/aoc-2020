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
    var data_lines = try file_util.dayFileLines(alloc, 1, "expense_report.txt");
    defer data_lines.deinit();
    
    var nums = std.ArrayList(i32).init(alloc);
    defer nums.deinit();

    while (try data_lines.next()) |line| {
        try nums.append(try std.fmt.parseInt(i32, line, 10));
    }

    return Solution{
        .prod2 = findSumProduct2(nums.items, 2020),
        .prod3 = findSumProduct3(nums.items, 2020),
    };
}

const expectEqual = std.testing.expectEqual;

test "findSumProduct2 contains sum" {
    expectEqual(findSumProduct2(&[_]i32{ 5, 6, 7, 20 }, 26), 120);
}

test "findSumProduct2 single element" {
    expectEqual(findSumProduct2(&[_]i32{1}, 5), null);
}

test "findSumProduct2 does not contain sum" {
    expectEqual(findSumProduct2(&[_]i32{ 5, 6, 7 }, 14), null);
}

test "findSumProduct3 contains sum" {
    expectEqual(findSumProduct3(&[_]i32{ 5, 6, 7, 20 }, 33),  840);
}

test "findSumProduct3 single element" {
    expectEqual(findSumProduct3(&[_]i32{1}, 5), null);
}

test "findSumProduct3 two elements" {
    expectEqual(findSumProduct3(&[_]i32{ 1, 4 }, 5), null);
}

test "findSumProduct3 does not contain sum" {
    expectEqual(findSumProduct3(&[_]i32{ 5, 7, 7 }, 14), null);
}
