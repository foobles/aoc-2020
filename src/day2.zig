const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;

const Allocator = std.mem.Allocator;

const Solution = struct { count: usize };

pub fn solve(alloc: *Allocator) !Solution {
    var x = Parser{ .str = "453 world" };
    return Solution{ .count = try x.unsigned(usize) };
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

    fn expect(self: *Parser, any_of: []const u8) ParseError!u8 {
        const next = try self.advance();
        return if (mem.indexOfScalar(u8, any_of, next) != null)
            next
        else
            error.UnexpectedCharacter;
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

test "expect success" {
    var p = Parser{ .str = "it" };
    expectEqual(p.expect("bdi"), 'i');
    expectEqual(p.expect("ght"), 't');
    expectEqual(p.advance(), error.NoCharacter);
}

test "expect fail" {
    var p = Parser{ .str = "it" };
    expectEqual(p.expect("12345"), error.UnexpectedCharacter);
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
