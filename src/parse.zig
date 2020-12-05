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

        pub const Self = @This();
        pub const Output = ParseOutput;

        pub fn run(self: Self, state: *ParseState) ParseError!ParseOutput {
            return runFn(self.context, state);
        }

        pub fn runSafe(self: Self, state: *ParseState) ParseError!ParseOutput {
            var new_state = state.*;
            const ret = try runFn(self.context, &new_state);
            state.* = new_state;
            return ret;
        }

        pub fn repeat(self: Self, state: *ParseState) Repeat(Self) {
            return .{ .inner = self, .state = state };
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

// TODO Tests 
pub const Any = Parser(void, u8, struct {
    fn run(_: void, state: *ParseState) ParseError!u8 {
        return state.advance();
    }
}.run);

pub fn any() Any {
    return .{ .context = {} };
}

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

pub fn fnParser(context: anytype, comptime T: type, comptime f: fn (@TypeOf(context), *ParseState) ParseError!T) Parser(@TypeOf(context), T, f) {
    return .{ .context = context };
}

pub const ExpectChar = Parser([]const u8, u8, struct {
    fn run(chars: []const u8, state: *ParseState) ParseError!u8 {
        const c = try state.advance();
        return if (mem.indexOfScalar(u8, chars, c) != null)
            c 
        else 
            error.UnexpectedToken;
    }
}.run);

pub fn expectChar(chars: []const u8) ExpectChar {
    return .{ .context = chars };
}

pub fn Repeat(comptime Inner: type) type {
    return struct {
        inner: Inner,
        state: *ParseState,

        pub fn next(self: @This()) ?Inner.Output {
            return self.inner.runSafe(self.state) catch null;
        }
    };
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

test "expect char" {
    var p = ParseState{ .str = "abc" };
    expectEqual(expectChar("ab").run(&p), 'a');
    expectEqual(expectChar("ab").run(&p), 'b');
    expectEqual(expectChar("ab").run(&p), error.UnexpectedToken);
}

test "expect char no input" {
    var p = ParseState {.str = "a" };
    expectEqual(expectChar("a").run(&p), 'a');
    expectEqual(expectChar("a").run(&p), error.EndOfStream);
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

test "fnParser" {
    var state = ParseState{ .str = "hello" };
    const ctx: []const u8 = &[2]u8{ 'h', 'e' };
    const parser = fnParser(ctx, [4]u8, struct {
        fn run(context: []const u8, s: *ParseState) ParseError![4]u8 {
            var ret = std.mem.zeroes([4]u8);
            var i: usize = 0;
            while (s.advance()) |c| : (i += 1) {
                if (i == ret.len) break;
                ret[i] = c;
                if (std.mem.indexOfScalar(u8, ctx, c) == null) break;
            } else |_| {}
            return ret;
        }
    }.run);
    expectEqual(parser.run(&state), [_]u8{ 'h', 'e', 'l', 0 });
}

test "repeat" {
    var state = ParseState{ .str = "HelloHelloHelloGoodbye" };
    const iter = expectString("Hello").repeat(&state);
    var i: usize = 0;
    while (iter.next()) |_| {
        i += 1;
    }
    expectEqual(i, 3);
    expectEqualSlices(u8, state.remaining(), "Goodbye");
}

test "run safe" {
    var state = ParseState{.str = "aaabbb" };

    const parser = expectChar("a");
    expectEqual(parser.runSafe(&state), 'a');
    expectEqual(parser.runSafe(&state), 'a');
    expectEqual(parser.runSafe(&state), 'a');
    expectEqual(parser.runSafe(&state), error.UnexpectedToken);
    expectEqualSlices(u8, state.remaining(), "bbb");
}