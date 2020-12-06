const std = @import("std");
const parse = @import("parse.zig");
const file_util = @import("file_util.zig");
const mem = std.mem;
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
        var map = try parsePassport(&state, alloc);
        defer freeOwningStringHashSet(alloc, &map);
        if (map.contains("byr") and
            map.contains("iyr") and
            map.contains("eyr") and
            map.contains("hgt") and
            map.contains("hcl") and
            map.contains("ecl") and
            map.contains("pid"))
        {
            count += 1;
        }
    }

    return Solution{ .valid_passports = count };
}

fn parsePassport(state: *ParseState, alloc: *Allocator) !StringHashMap(void) {
    var ret = StringHashMap(void).init(alloc);
    errdefer freeOwningStringHashSet(alloc, &ret);

    const entries = state.repeat(parsePassportEntry, .{alloc});
    while (try entries.next()) |e| {
        try ret.put(e, {});
    }
    return ret;
}

fn parsePassportEntry(state: *ParseState, alloc: *Allocator) ![]const u8 {
    try state.skipWhitespace();
    const untilColon = (try state.bytesUntil(ParseState.expectChar, .{":"}));
    if (untilColon.val == null)
        return state.setError(error.UnexpectedToken);
    _ = try state.bytesUntil(ParseState.expectChar, .{&ascii.spaces});
    return alloc.dupe(u8, untilColon.skipped);
}

fn freeOwningStringHashSet(alloc: *Allocator, set: *StringHashMap(void)) void {
    var iter = set.iterator();
    while (iter.next()) |entry| {
        alloc.free(entry.key);
    }
    set.deinit();
}
