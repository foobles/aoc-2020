const std = @import("std");
const file_util = @import("file_util.zig");
const mem = std.mem;
const ascii = std.ascii;

const Allocator = std.mem.Allocator;

const Solution = struct { range_valid_count: usize, placement_valid_count: usize };

pub fn solve(alloc: *Allocator) !Solution {
    const password_file = try file_util.getDayFile(alloc, 2, "passwords.txt");
    defer password_file.close();
    const file_reader = std.io.bufferedReader(password_file.reader()).reader();

    var line_buf: [256]u8 = undefined;
    var range_valid_count: usize = 0;
    var placement_valid_count: usize = 0;
    while (try file_util.readLine(file_reader, &line_buf)) |line| {
        const rule = try parseLine(line);
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

fn parseLine(line: []const u8) Parser.ParseError!Rule {
    var parser = Parser{ .str = line };
    const first_n = try parser.unsigned(usize);
    try parser.expectString("-");
    const second_n = try parser.unsigned(usize);
    try parser.expectString(" ");
    const char = try parser.advance();
    try parser.expectString(": ");

    return Rule{
        .first_n = first_n,
        .second_n = second_n,
        .char = char,
        .string = parser.remaining(),
    };
}

const Parser = struct {
    str: []const u8,

    const ParseError = error{ UnexpectedCharacter, NoCharacter };

    fn remaining(self: Parser) []const u8 {
        return self.str;
    }

    fn advance(self: *Parser) ParseError!u8 {
        if (self.str.len > 0) {
            const ret = self.str[0];
            self.str = self.str[1..];
            return ret;
        } else {
            return error.NoCharacter;
        }
    }

    fn expectString(self: *Parser, string: []const u8) ParseError!void {
        if (self.str.len < string.len)
            return error.NoCharacter;

        if (mem.eql(u8, self.str[0..string.len], string))
            self.str = self.str[string.len..]
        else
            return error.UnexpectedCharacter;
    }

    fn unsigned(self: *Parser, comptime T: type) ParseError!T {
        if (self.str.len == 0)
            return error.NoCharacter;

        var ret: T = 0;
        const idx = for (self.str) |cur, i| {
            if (ascii.isDigit(cur)) {
                ret *= 10;
                ret += @intCast(T, cur - '0');
            } else if (i == 0)
                return error.UnexpectedCharacter
            else
                break i;
        } else
            self.str.len;
        self.str = self.str[idx..];
        return ret;
    }
};

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test "parse next" {
    var p = Parser{ .str = "hello" };
    const c = try p.advance();
    expectEqual(c, 'h');
    expectEqualSlices(u8, p.remaining(), "ello");
}

test "parse next empty" {
    var p = Parser{ .str = "hi" };
    expectEqual(p.advance(), 'h');
    expectEqual(p.advance(), 'i');
    expectEqual(p.advance(), error.NoCharacter);
}

test "expect str" {
    var p = Parser { .str = "hello world" };
    try p.expectString("hello");
    expectEqualSlices(u8, p.remaining(), " world");
}

test "expect str not enough characters" {
    var p = Parser { .str = "cup" };
    expectEqual(p.expectString("cupholder"), error.NoCharacter);
}

test "expect str wrong characters" {
    var p = Parser { .str = "help" };
    expectEqual(p.expectString("felt"), error.UnexpectedCharacter);
}

test "parse number with eof" {
    var p = Parser{ .str = "123" };
    expectEqual(p.unsigned(i32), 123);
    expectEqual(p.remaining().len, 0);
}

test "parse number in blob" {
    var p = Parser{ .str = "123hello" };
    expectEqual(p.unsigned(i32), 123);
    expectEqualSlices(u8, p.remaining(), "hello");
}

test "parse number fail no digits" {
    var p = Parser{ .str = "hello" };
    expectEqual(p.unsigned(i32), error.UnexpectedCharacter);
}

test "parse number fail empty string" {
    var p = Parser{ .str = "" };
    expectEqual(p.unsigned(i32), error.NoCharacter);
}

test "parse rule" {
    const line = "5-10 h: asdfashdfa";
    const rule = try parseLine(line);
    expectEqual(rule.first_n, 5);
    expectEqual(rule.second_n, 10);
    expectEqual(rule.char, 'h');
    expectEqualSlices(u8, rule.string, "asdfashdfa");
}

test "parse rule" {
    const line = "545-10232 h: asdfashdfa";
    const rule = try parseLine(line);
    expectEqual(rule.first_n, 545);
    expectEqual(rule.second_n, 10232);
    expectEqual(rule.char, 'h');
    expectEqualSlices(u8, rule.string, "asdfashdfa");
}