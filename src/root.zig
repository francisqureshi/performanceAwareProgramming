//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

pub fn getBlockSize(file: std.fs.File) !usize {
    // Get optimal block size for this file's filesystem
    const stat = try std.posix.fstat(file.handle);
    const block_size: usize = @intCast(stat.blksize);
    return block_size;
}

pub fn importData(filepath: []const u8) !void {
    const filename = std.fs.path.basename(filepath);
    const file = try std.fs.openFileAbsolute(filepath, .{ .mode = .read_only });
    defer file.close();

    const file_stat = try file.stat();

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const full_path = try std.fs.realpath(filepath, &buf);

    std.debug.print("File: {s}\n", .{filename});
    std.debug.print("Size: {} bytes\n", .{file_stat.size});
    std.debug.print("Full path: {s}\n", .{full_path});
    std.debug.print("\n--- File Contents ---\n", .{});

    const block_size = try getBlockSize(file);
    const buffer_size = block_size * 32; // 32x block size

    // Allocate buffers dynamically based on block size
    const page_allocator = std.heap.page_allocator;
    const buf_out = try page_allocator.alloc(u8, buffer_size);
    defer page_allocator.free(buf_out);
    const buf_file = try page_allocator.alloc(u8, buffer_size);
    defer page_allocator.free(buf_file);
    const buf_read = try page_allocator.alloc(u8, buffer_size);
    defer page_allocator.free(buf_read);

    const stdout = std.fs.File.stdout();
    var out_writer = stdout.writer(buf_out);
    const out = &out_writer.interface;

    var reader = file.reader(buf_file);

    while (true) {
        // Fill buffer and get what's available
        reader.interface.fillMore() catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        const chunk = reader.interface.buffered();
        if (chunk.len == 0) break;

        try out.writeAll(chunk);
        reader.interface.tossBuffered();
    }
    try out.flush();
}
