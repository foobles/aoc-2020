const std = @import("std");
const file_util = @import("file_util.zig");

const mem = std.mem;

const Allocator = std.mem.Allocator;

pub const Solution = struct {
    any_sum: usize,
    all_sum: usize,
};

pub fn solve(alloc: *Allocator) !Solution {
    const answer_file = try file_util.getDayFile(alloc, 6, "answers.txt");
    defer answer_file.close();
    const file_reader = std.io.bufferedReader(answer_file.reader()).reader();

    var any_sum: usize = 0;
    var all_sum: usize = 0;
    var answers = mem.zeroes([26]usize);
    var people: usize = 0;

    var buf: [256]u8 = undefined;
    while (try file_util.readLine(file_reader, &buf)) |line| {
        if (line.len > 0) {
            for (line) |c| {
                answers[c - 'a'] += 1;
            }
            people += 1;
        } else {
            const flush = flush_answers(&answers, people);
            any_sum += flush.any;
            all_sum += flush.all;
            people = 0;
        }
    }
    if (people > 0) {
        const flush = flush_answers(&answers, people);
        any_sum += flush.any;
        all_sum += flush.all;
    }

    return Solution{
        .any_sum = any_sum,
        .all_sum = all_sum,
    };
}

const FlushResult = struct { all: usize, any: usize };

fn flush_answers(answers: []usize, people: usize) FlushResult {
    var ret = FlushResult{
        .all = 0,
        .any = 0,
    };
    for (answers) |*n| {
        if (n.* != 0) {
            ret.any += 1;
        }
        if (n.* == people) {
            ret.all += 1;
        }

        n.* = 0;
    }
    return ret;
}
