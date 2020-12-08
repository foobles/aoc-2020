const std = @import("std");
const parse = @import("parse.zig");
const file_util = @import("file_util.zig");
const mem = std.mem;
const fmt = std.fmt;
const ascii = std.ascii;

const ParseError = parse.ParseError;
const ParseState = parse.ParseState;
const Parser = parse.Parser;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Solution = struct {
    valid_passports: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    const pp_file = try file_util.getDayFile(alloc, 4, "passports.txt");
    defer pp_file.close();
    const pp_reader = std.io.bufferedReader(pp_file.reader()).reader();
    const pp_bytes = try pp_reader.readAllAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(pp_bytes);

    var count: usize = 0;
    var pps = mem.split(pp_bytes, "\r\n\r\n");
    while (pps.next()) |pp| {
        var state = ParseState{ .str = pp };
        var passport = parsePassport(&state) catch |e| switch (e) {
            error.ParseError => continue,
            else => return e,
        };
        if (verifyPassport(passport)) {
            count += 1;
        }
    }

    return Solution{ .valid_passports = count };
}

fn verifyPassport(p: Passport) bool {
    return (1920 <= p.byr and p.byr <= 2002) and
        (2010 <= p.iyr and p.iyr <= 2020) and
        (2020 <= p.eyr and p.eyr <= 2030) and
        switch (p.hgt) {
        .Cm => |n| (150 <= n and n <= 193),
        .In => |n| (59 <= n and n <= 76),
    };
}

const Passport = struct {
    byr: u16,
    iyr: u16,
    eyr: u16,
    hgt: union(enum) { Cm: u16, In: u16 },
    hcl: [3]u8,
    ecl: EyeColor,
    pid: u32,
};

const EyeColor = enum { Amb, Blu, Brn, Gry, Grn, Hzl, Oth };

fn parsePassport(state: *ParseState) !Passport {
    var ret: Passport = undefined;
    var set_fields: u8 = 0;

    const entries = state.repeat(parseEntry, .{&ret});
    while (try entries.next()) |field| {
        set_fields |= field;
    }
    if ((set_fields & ((1 << 7) - 1)) != 0b1_111_111)
        return state.parseError(null);

    return ret;
}

fn parseEntry(state: *ParseState, output: *Passport) !u8 {
    try state.skipWhitespace();
    const untilColon = try state.bytesUntil(ParseState.expectChar, .{": "});
    if (untilColon.val != @as(u8, ':'))
        return state.parseError(null);

    const key = untilColon.skipped;
    var ret: u8 = undefined;
    if (mem.eql(u8, key, "byr")) {
        output.byr = try state.unsigned(u16);
        return 1 << 0;
    } else if (mem.eql(u8, key, "iyr")) {
        output.iyr = try state.unsigned(u16);
        return 1 << 1;
    } else if (mem.eql(u8, key, "eyr")) {
        output.eyr = try state.unsigned(u16);
        return 1 << 2;
    } else if (mem.eql(u8, key, "hgt")) {
        const n = try state.unsigned(u16);
        output.hgt = if (try state.runSafe(ParseState.expectString, .{"cm"})) |_|
            .{ .Cm = n }
        else if (try state.runSafe(ParseState.expectString, .{"in"})) |_|
            .{ .In = n }
        else
            return state.parseError(error.InvalidHeight);
        return 1 << 3;
    } else if (mem.eql(u8, key, "hcl")) {
        _ = try state.expectChar("#");
        output.hcl[0] = try parseHexByte(state);
        output.hcl[1] = try parseHexByte(state);
        output.hcl[2] = try parseHexByte(state);
        return 1 << 4;
    } else if (mem.eql(u8, key, "ecl")) {
        output.ecl = if (try state.runSafe(ParseState.expectString, .{"amb"})) |_|
            EyeColor.Amb
        else if (try state.runSafe(ParseState.expectString, .{"blu"})) |_|
            EyeColor.Blu
        else if (try state.runSafe(ParseState.expectString, .{"brn"})) |_|
            EyeColor.Brn
        else if (try state.runSafe(ParseState.expectString, .{"gry"})) |_|
            EyeColor.Gry
        else if (try state.runSafe(ParseState.expectString, .{"grn"})) |_|
            EyeColor.Grn
        else if (try state.runSafe(ParseState.expectString, .{"hzl"})) |_|
            EyeColor.Hzl
        else if (try state.runSafe(ParseState.expectString, .{"oth"})) |_|
            EyeColor.Oth
        else
            return state.parseError(error.InvalidEyeColor);
        return 1 << 5;
    } else if (mem.eql(u8, key, "pid")) {
        const prev_str = state.str;
        output.pid = try state.unsigned(u32);
        if (@ptrToInt(state.str.ptr) - @ptrToInt(prev_str.ptr) != 9)
            return state.parseError(error.InvalidIdLen);
        return 1 << 6;
    } else if (mem.eql(u8, key, "cid")) {
        _ = try state.bytesUntil(ParseState.expectChar, .{" \n"});
        return 1 << 7; // unused
    }
    return state.parseError(error.InvalidKey);
}

fn parseHexByte(state: *ParseState) !u8 {
    const d1 = try state.expectCharPred(ascii.isXDigit);
    const d2 = try state.expectCharPred(ascii.isXDigit);
    const high = 16 * (fmt.charToDigit(d1, 16) catch unreachable);
    const low = fmt.charToDigit(d2, 16) catch unreachable;
    return high + low;
}
