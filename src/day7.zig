const std = @import("std");
const file_util = @import("file_util.zig");
const parse = @import("parse.zig");
const mem = std.mem;

const Allocator = std.mem.Allocator;
const StringHashMapUnmanaged = std.StringHashMapUnmanaged;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ParseState = parse.ParseState;

const assert = std.debug.assert;

pub const Solution = struct {
    gold_contained_by: usize,
    gold_contains: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    var bag_lines = try file_util.dayFileLines(alloc, 7, "bags.txt");
    defer bag_lines.deinit();

    var rule_map_contains = RuleMap.init(alloc);
    defer rule_map_contains.deinit();

    var rule_map_contained_by = RuleMap.init(alloc);
    defer rule_map_contained_by.deinit();
    while (try bag_lines.next()) |line| {
        var state = ParseState{ .str = line };
        try parseRule(&state, &rule_map_contains, &rule_map_contained_by);
    }

    return Solution{
        .gold_contained_by = try rule_map_contained_by.count_contain("shiny gold", .{.track_repeats = true}),
        .gold_contains = try rule_map_contains.count_contain("shiny gold", .{.track_repeats = false}),
    };
}

fn parseRule(state: *ParseState, map_contains: *RuleMap, map_contained_by: *RuleMap) !void {
    const rule_name = ((try state.skipUntil(ParseState.expectString, .{" bags contain "})) orelse return state.parseError(error.NoBagContents)).skipped;

    var bag_contents = state.repeat(parseBagContent, .{});
    while (try bag_contents.next()) |content| {
        try map_contains.insert_content(rule_name, content.name, content.count);
        try map_contained_by.insert_content(content.name, rule_name, 1);
    }
}

fn parseBagContent(state: *ParseState) !RuleMap.BagData {
    try state.skipWhitespace();
    const count = try state.unsigned(usize);
    try state.skipWhitespace();
    const name = ((try state.skipUntil(ParseState.expectString, .{" bag"})) orelse return state.parseError(error.BagContentNoName)).skipped;
    _ = try state.skipUntil(ParseState.expectString, .{", "});

    return RuleMap.BagData{
        .name = name,
        .count = count,
    };
}

const RuleMap = struct {
    alloc: *Allocator,
    map: InnerMap,

    const InnerMap = StringHashMapUnmanaged(ArrayListUnmanaged(BagData));

    fn init(alloc: *Allocator) RuleMap {
        return .{
            .alloc = alloc,
            .map = InnerMap.init(alloc),
        };
    }

    fn deinit(self: *RuleMap) void {
        var map_iter = self.map.iterator();
        while (map_iter.next()) |entry| {
            self.alloc.free(entry.key);
            entry.value.deinit(self.alloc);
        }
        self.map.deinit(self.alloc);
    }

    fn insert_content(self: *RuleMap, name: []const u8, content_name: []const u8, count: usize) !void {
        const owned_content_name = if (self.map.getEntry(content_name)) |entry|
            entry.key
        else blk: {
            const content_name_dupe = try self.alloc.dupe(u8, content_name);
            try self.map.put(self.alloc, content_name_dupe, .{});
            break :blk content_name_dupe;
        };

        const content_arr = blk: {
            var res = try self.map.getOrPut(self.alloc, name);
            if (!res.found_existing) {
                errdefer _ = self.map.remove(name);
                res.entry.key = try self.alloc.dupe(u8, name);
                res.entry.value = .{};
            }
            break :blk &res.entry.value;
        };

        try content_arr.append(self.alloc, .{ .name = owned_content_name, .count = count });
    }

    fn count_contain(self: RuleMap, name: []const u8, comptime options: anytype) !usize {
        const track_repeats: bool = options.track_repeats;
        const StringSet = StringHashMapUnmanaged(void);
        var used_string_map: StringSet = if (track_repeats)
            StringSet.init(self.alloc)
        else 
            undefined;
        defer if (track_repeats) used_string_map.deinit(self.alloc);

        var data_list: [256]BagData = undefined;
        var new_list: [256]BagData = undefined;
        data_list[0] = .{ .name = name, .count = 1 };
        var len: usize = 1;
        var ret: usize = 0;

        while (len > 0) {
            var new_len: usize = 0;
            for (data_list[0..len]) |data| {
                const arr = self.map.get(data.name) orelse return error.NoBag;
                for (arr.items) |s| {
                    const should_count = if (track_repeats) blk: {
                        const gpe = try used_string_map.getOrPut(self.alloc, s.name);
                        break :blk !gpe.found_existing;
                    } else 
                        true;

                    if (should_count) {
                        ret += s.count * data.count;

                        assert(new_len < 256);
                        new_list[new_len] = s;
                        new_list[new_len].count *= data.count;
                        new_len += 1;
                    }
                }
            }
            data_list = new_list;
            len = new_len;
        }

        return ret;
    }

    const BagData = struct {
        name: []const u8, // refers to data owned by the key in the map
        count: usize,
    };
};
