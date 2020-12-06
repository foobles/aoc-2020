const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;

pub const ParseError = error{
    UnexpectedToken,
    EndOfStream,
};

pub const ParseState = struct {
    str: []const u8,
    err: ?anyerror = null,

    pub fn parseError(self: *ParseState, err: ?anyerror) error{ParseError} {
        if (err) |e|
            self.err = e;
        return error.ParseError;
    }

    pub fn remaining(self: ParseState) []const u8 {
        return self.str;
    }

    pub fn advance(self: *ParseState) !u8 {
        if (self.str.len > 0) {
            const ret = self.str[0];
            self.str = self.str[1..];
            return ret;
        } else {
            return self.parseError(error.EndOfStream);
        }
    }

    pub fn expectCharPred(self: *ParseState, comptime pred: fn (u8) bool) !u8 {
        const c = try self.advance();
        return if (pred(c))
            c
        else
            self.parseError(error.UnexpectedToken);
    }

    pub fn expectChar(self: *ParseState, chars: []const u8) !u8 {
        const c = try self.advance();
        return if (mem.indexOfScalar(u8, chars, c) != null)
            c
        else
            self.parseError(error.UnexpectedToken);
    }

    pub fn expectString(self: *ParseState, string: []const u8) !void {
        if (self.str.len < string.len)
            return self.parseError(error.EndOfStream);

        if (mem.eql(u8, self.str[0..string.len], string))
            self.str = self.str[string.len..]
        else
            return self.parseError(error.UnexpectedToken);
    }

    pub fn unsigned(self: *ParseState, comptime T: type) !T {
        if (self.str.len == 0)
            return self.parseError(error.EndOfStream);

        var ret: T = 0;
        const idx = for (self.str) |cur, i| {
            if (ascii.isDigit(cur)) {
                if (@mulWithOverflow(T, ret, 10, &ret))
                    return self.parseError(error.LiteralTooLarge);

                if (@addWithOverflow(T, ret, @intCast(T, cur - '0'), &ret))
                    return self.parseError(error.LiteralTooLarge);
            } else if (i == 0)
                return self.parseError(error.UnexpectedToken)
            else
                break i;
        } else
            self.str.len;
        self.str = self.str[idx..];
        return ret;
    }

    pub fn run_safe(self: *ParseState, comptime f: anytype, args: anytype) !ParseFnReturnType(f) {
        var new_state = self.*;
        const ret = try new_state.run(f, args);
        self.* = new_state;
        return ret;
    }

    pub fn run(self: *ParseState, comptime f: anytype, args: anytype) !ParseFnReturnType(f) {
        return @call(.{}, f, .{self} ++ args);
    }

    pub fn repeat(self: *ParseState, comptime f: anytype, args: anytype) Repeat(f, @TypeOf(args)) {
        return .{ .state = self, .context = args };
    }

    pub fn bytesUntil(self: *ParseState, comptime f: anytype, args: anytype) !BytesUntil(f) {
        for (self.str) |_, i| {
            var substate = ParseState{ .str = self.str[i..] };
            if (substate.run_safe(f, args)) |x| {
                const skipped = self.str[0..i];
                self.str = substate.str;
                return BytesUntil(f){ .skipped = skipped, .val = x };
            } else |e| switch (e) {
                error.ParseError => {},
                else => return e,
            }
        }
        self.str = "";
        return BytesUntil(f){ .skipped = self.str, .val = null };
    }

    pub fn skipWhitespace(self: *ParseState) !void {
        const iter = self.repeat(ParseState.expectChar, .{&ascii.spaces});
        while (try iter.next()) |_| {}
    }
};

pub fn BytesUntil(comptime f: anytype) type {
    return struct {
        skipped: []const u8,
        val: ?ParseFnReturnType(f),
    };
}

pub fn Repeat(comptime f: anytype, comptime ArgT: type) type {
    return struct {
        state: *ParseState,
        context: ArgT,

        pub fn next(self: @This()) !?ParseFnReturnType(f) {
            return self.state.run_safe(f, self.context) catch |e| switch (e) {
                error.ParseError => return null,
                else => e,
            };
        }
    };
}

fn ParseFnReturnType(comptime f: anytype) type {
    return @typeInfo(@typeInfo(@TypeOf(f)).Fn.return_type.?).ErrorUnion.payload;
}

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

// test "parse next" {
//     var p = ParseState{ .str = "hello" };
//     const c = try p.advance();
//     expectEqual(c, 'h');
//     expectEqualSlices(u8, p.remaining(), "ello");
// }

// test "parse next empty" {
//     var p = ParseState{ .str = "hi" };
//     expectEqual(p.advance(), 'h');
//     expectEqual(p.advance(), 'i');
//     expectEqual(p.advance(), error.EndOfStream);
// }

// test "expect str" {
//     var p = ParseState{ .str = "hello world" };
//     try expectString("hello").run(&p);
//     expectEqualSlices(u8, p.remaining(), " world");
// }

// test "expect str not enough characters" {
//     var p = ParseState{ .str = "cup" };
//     expectEqual(expectString("cupholder").run(&p), error.EndOfStream);
// }

// test "expect str wrong characters" {
//     var p = ParseState{ .str = "help" };
//     expectEqual(expectString("felt").run(&p), error.UnexpectedToken);
// }

// test "expect char" {
//     var p = ParseState{ .str = "abc" };
//     expectEqual(expectChar("ab").run(&p), 'a');
//     expectEqual(expectChar("ab").run(&p), 'b');
//     expectEqual(expectChar("ab").run(&p), error.UnexpectedToken);
// }

// test "expect char no input" {
//     var p = ParseState{ .str = "a" };
//     expectEqual(expectChar("a").run(&p), 'a');
//     expectEqual(expectChar("a").run(&p), error.EndOfStream);
// }

// test "parse number with eof" {
//     var p = ParseState{ .str = "123" };
//     expectEqual(unsigned(i32).run(&p), 123);
//     expectEqual(p.remaining().len, 0);
// }

// test "parse number in blob" {
//     var p = ParseState{ .str = "123hello" };
//     expectEqual(unsigned(i32).run(&p), 123);
//     expectEqualSlices(u8, p.remaining(), "hello");
// }

// test "parse number fail no digits" {
//     var p = ParseState{ .str = "hello" };
//     expectEqual(unsigned(i32).run(&p), error.UnexpectedToken);
// }

// test "parse number fail empty string" {
//     var p = ParseState{ .str = "" };
//     expectEqual(unsigned(i32).run(&p), error.EndOfStream);
// }

// test "fnParser" {
//     var state = ParseState{ .str = "hello" };
//     const ctx: []const u8 = &[2]u8{ 'h', 'e' };
//     const parser = fnParser(ctx, [4]u8, struct {
//         fn run(context: []const u8, s: *ParseState) ParseError![4]u8 {
//             var ret = std.mem.zeroes([4]u8);
//             var i: usize = 0;
//             while (s.advance()) |c| : (i += 1) {
//                 if (i == ret.len) break;
//                 ret[i] = c;
//                 if (std.mem.indexOfScalar(u8, ctx, c) == null) break;
//             } else |_| {}
//             return ret;
//         }
//     }.run);
//     expectEqual(parser.run(&state), [_]u8{ 'h', 'e', 'l', 0 });
// }

// test "repeat" {
//     var state = ParseState{ .str = "HelloHelloHelloGoodbye" };
//     const iter = expectString("Hello").repeat(&state);
//     var i: usize = 0;
//     while (iter.next()) |_| {
//         i += 1;
//     }
//     expectEqual(i, 3);
//     expectEqualSlices(u8, state.remaining(), "Goodbye");
// }

// test "run safe" {
//     var state = ParseState{ .str = "aaabbb" };

//     const parser = expectChar("a");
//     expectEqual(parser.runSafe(&state), 'a');
//     expectEqual(parser.runSafe(&state), 'a');
//     expectEqual(parser.runSafe(&state), 'a');
//     expectEqual(parser.runSafe(&state), error.UnexpectedToken);
//     expectEqualSlices(u8, state.remaining(), "bbb");
// }
