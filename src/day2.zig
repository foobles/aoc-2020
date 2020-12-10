const std = @import("std");
const file_util = @import("file_util.zig");
const mem = std.mem;
const ascii = std.ascii;
const parse = @import("parse.zig");

const ParseState = parse.ParseState;
const Allocator = std.mem.Allocator;

const Solution = struct { range_valid_count: usize, placement_valid_count: usize };

pub fn solve(alloc: *Allocator) !Solution {
    var password_lines = try file_util.dayFileLines(alloc, 2, "passwords.txt");
    defer password_lines.deinit();

    var range_valid_count: usize = 0;
    var placement_valid_count: usize = 0;
    while (try password_lines.next()) |line| {
        var state = ParseState{ .str = line };
        const rule = try parseRule(&state);
        if (rule.isRangeCountValid()) {
            range_valid_count += 1;
        }
        if (rule.isPlacementValid()) {
            placement_valid_count += 1;
        }
    }
    return Solution{
        .range_valid_count = range_valid_count,
        .placement_valid_count = placement_valid_count,
    };
}

const Rule = struct {
    first_n: usize,
    second_n: usize,
    char: u8,
    string: []const u8,

    fn isRangeCountValid(self: Rule) bool {
        const count = mem.count(u8, self.string, &[_]u8{self.char});
        return self.first_n <= count and count <= self.second_n;
    }

    fn isPlacementValid(self: Rule) bool {
        return (self.string[self.first_n - 1] == self.char) !=
            (self.string[self.second_n - 1] == self.char);
    }
};

fn parseRule(state: *ParseState) !Rule {
    const first_n = try state.unsigned(usize);
    try state.expectString("-");
    const second_n = try state.unsigned(usize);
    try state.expectString(" ");
    const char = try state.advance();
    try state.expectString(": ");

    return Rule{
        .first_n = first_n,
        .second_n = second_n,
        .char = char,
        .string = state.remaining(),
    };
}

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

// test "parse rule" {
//     var state = ParseState { .str = "545-10232 h: asdfashdfa" };
//     const rule = try (ParseRule { .context = {}}).run(&state);
//     expectEqual(rule.first_n, 545);
//     expectEqual(rule.second_n, 10232);
//     expectEqual(rule.char, 'h');
//     expectEqualSlices(u8, rule.string, "asdfashdfa");
// }