const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;

pub fn Parser(
    comptime Context: type,
    comptime ParseOutput: type,
    comptime runFn: fn (Context, *ParseState) ParseError!ParseOutput,
) type {
    return struct {
        context: Context,

        const Output = ParseOutput;

        pub fn run(self: @This(), state: *ParseState) ParseError!ParseOutput {
            return runFn(self.context, state);
        }
    };
}

pub const ParseError = error{
    UnexpectedToken,
    EndOfStream,
};

pub const ParseState = struct {
    str: []const u8,

    pub fn remaining(self: ParseState) []const u8 {
        return self.str;
    }

    pub fn advance(self: *ParseState) ParseError!u8 {
        if (self.str.len > 0) {
            const ret = self.str[0];
            self.str = self.str[1..];
            return ret;
        } else {
            return error.EndOfStream;
        }
    }
};

pub fn Unsigned(comptime T: type) type {
    return Parser(void, T, struct {
        fn run(_context: void, state: *ParseState) ParseError!T {
            if (state.str.len == 0)
                return error.EndOfStream;

            var ret: T = 0;
            const idx = for (state.str) |cur, i| {
                if (ascii.isDigit(cur)) {
                    ret *= 10;
                    ret += @intCast(T, cur - '0');
                } else if (i == 0)
                    return error.UnexpectedToken
                else
                    break i;
            } else
                state.str.len;
            state.str = state.str[idx..];
            return ret;
        }
    }.run);
}

pub fn unsigned(comptime T: type) Unsigned(T) {
    return .{ .context = {} };
}

pub const ExpectString = Parser([]const u8, void, struct {
    fn run(string: []const u8, state: *ParseState) ParseError!void {
        if (state.str.len < string.len)
            return error.EndOfStream;

        if (mem.eql(u8, state.str[0..string.len], string))
            state.str = state.str[string.len..]
        else
            return error.UnexpectedToken;
    }
}.run);

pub fn expectString(string: []const u8) ExpectString {
    return .{ .context = string };
}


const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;


test "parse next" {
    var p = ParseState{ .str = "hello" };
    const c = try p.advance();
    expectEqual(c, 'h');
    expectEqualSlices(u8, p.remaining(), "ello");
}

test "parse next empty" {
    var p = ParseState{ .str = "hi" };
    expectEqual(p.advance(), 'h');
    expectEqual(p.advance(), 'i');
    expectEqual(p.advance(), error.EndOfStream);
}

test "expect str" {
    var p = ParseState{ .str = "hello world" };
    try expectString("hello").run(&p);
    expectEqualSlices(u8, p.remaining(), " world");
}

test "expect str not enough characters" {
    var p = ParseState{ .str = "cup" };
    expectEqual(expectString("cupholder").run(&p), error.EndOfStream);
}

test "expect str wrong characters" {
    var p = ParseState{ .str = "help" };
    expectEqual(expectString("felt").run(&p), error.UnexpectedToken);
}

test "parse number with eof" {
    var p = ParseState{ .str = "123" };
    expectEqual(unsigned(i32).run(&p), 123);
    expectEqual(p.remaining().len, 0);
}

test "parse number in blob" {
    var p = ParseState{ .str = "123hello" };
    expectEqual(unsigned(i32).run(&p), 123);
    expectEqualSlices(u8, p.remaining(), "hello");
}

test "parse number fail no digits" {
    var p = ParseState{ .str = "hello" };
    expectEqual(unsigned(i32).run(&p), error.UnexpectedToken);
}

test "parse number fail empty string" {
    var p = ParseState{ .str = "" };
    expectEqual(unsigned(i32).run(&p), error.EndOfStream);
}
