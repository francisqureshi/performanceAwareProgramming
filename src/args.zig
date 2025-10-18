const std = @import("std");
const pap = @import("performanceAwareProgramming");

pub const Command = enum {
    decode,
    main,
};

pub const ParsedArgs = struct {
    command: Command,
    input_file: ?[]const u8 = null,
    output_file: ?[]const u8 = null,
};

pub fn parseArgs(allocator: std.mem.Allocator) !ParsedArgs {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        return ParsedArgs{ .command = .main };
    }

    var result = ParsedArgs{ .command = .main };

    if (std.mem.eql(u8, args[1], "-decode")) {
        result.command = .decode;
        if (args.len >= 3) {
            result.input_file = try allocator.dupe(u8, args[2]);
        }
        if (args.len >= 4) {
            result.output_file = try allocator.dupe(u8, args[3]);
        }
    }

    return result;
}
