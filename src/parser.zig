
const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;

pub const Parser = struct {
    str: []const u8,

    pub const ParseError = error{ UnexpectedCharacter, NoCharacter };

    pub fn remaining(self: Parser) []const u8 {
        return self.str;
    }

    pub fn advance(self: *Parser) ParseError!u8 {
        if (self.str.len > 0) {
            const ret = self.str[0];
            self.str = self.str[1..];
            return ret;
        } else {
            return error.NoCharacter;
        }
    }

    pub fn expectString(self: *Parser, string: []const u8) ParseError!void {
        if (self.str.len < string.len)
            return error.NoCharacter;

        if (mem.eql(u8, self.str[0..string.len], string))
            self.str = self.str[string.len..]
        else
            return error.UnexpectedCharacter;
    }

    pub fn unsigned(self: *Parser, comptime T: type) ParseError!T {
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