const std = @import("std");
const fs = std.fs;
const io = std.io;
const fmt = std.fmt;
const mem = std.mem;
const ascii = std.ascii;

const File = fs.File;
const Allocator = std.mem.Allocator;
const BufferedReader = std.io.BufferedReader;

pub fn readLine(input: anytype, buf: []u8) !?[]const u8 {
    const raw_line = (try input.readUntilDelimiterOrEof(buf, '\n')) orelse return null;
    return mem.trim(u8, raw_line, &ascii.spaces);
}

pub fn getDayFile(alloc: *Allocator, day: u8, filename: []const u8) !File {
    var path_buf = try fmt.allocPrint(alloc, "data/day{}/{}", .{ day, filename });
    defer alloc.free(path_buf);
    return fs.cwd().openFile(path_buf, .{});
}

pub fn dayFileLines(alloc: *Allocator, day: u8, filename: []const u8) !FileLines {
    const file = try getDayFile(alloc, day, filename);
    return FileLines {
        .file = file,
        .buf_reader = io.bufferedReader(file.reader())
    };
}

pub const FileLines = struct {
    file: File,
    buf_reader: BufferedReader(4096, File.Reader),
    buf: [256]u8 = undefined,

    pub fn next(self: *FileLines) !?[]const u8 {
        return readLine(self.buf_reader.reader(), &self.buf);
    }

    pub fn deinit(self: FileLines) void {
        self.file.close();
    }
};