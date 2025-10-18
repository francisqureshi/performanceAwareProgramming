const std = @import("std");
const pap = @import("performanceAwareProgramming");

pub fn homeworkOne(filepath: []const u8) !void {
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

    var file_read_buffer: [1024]u8 = undefined;

    var stdout_buffer: [1024]u8 = undefined;

    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var reader = file.reader(&file_read_buffer);

    // Write ASM header
    try stdout.writeAll("; ========================================================================\n");
    try stdout.writeAll(";\n; fq 8086 ASM decoder...\n;\n");
    try stdout.print("; {s}.asm\n", .{filename});
    try stdout.writeAll("; ========================================================================\n\n");
    try stdout.writeAll("bits 16\n\n");

    // 8086 2 byte insrtuction
    // OpCode Byte (1)
    // | OpCode | D | W |
    //     6  +  1 + 1
    const OpCodeByte = enum(u6) {
        mov = 0b100010,
        add = 0b000000,
        sub = 0b001010,
        cmp = 0b001110,
        and_op = 0b001000,
        or_op = 0b000010,
        _,
    };

    const direction_bit = enum(u1) { source_is_reg = 0b0, destination_is_reg = 0b1 };
    const word_byte_bit = enum(u1) { byte_op = 0b0, word_op = 0b1 };

    // // Operand Byte (2)
    // // | Mod | Reg | Reg/Mem |
    // //    2  + 3  +   3
    const MOD_byte = enum(u2) { memory_mode = 0b00, memory_8bit_disp_mode = 0b01, memory_16bit_disp_mode = 0b10, register_mode = 0b11 };

    const REG_byte = enum(u3) { al = 0b000, cl = 0b001, dl = 0b010, bl = 0b011, ah = 0b100, ch = 0b101, dh = 0b110, bh = 0b111 };
    const REG_word = enum(u3) { ax = 0b000, cx = 0b001, dx = 0b010, bx = 0b011, sp = 0b100, bp = 0b101, si = 0b110, di = 0b111 };

    var byte_count: usize = 0;

    // Peek and decode instructions
    while (true) {
        // Peek first 2 bytes to decode and determine instruction length
        const initial_peek = reader.interface.peek(2) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        // Decode opcode byte (byte 0)
        const opcode_byte = initial_peek[0];
        const opcode = opcode_byte >> 2;
        const d_bit = (opcode_byte >> 1) & 0b1;
        const w_bit = opcode_byte & 0b1;

        const op_asm: OpCodeByte = @enumFromInt(opcode);
        const d_flag: direction_bit = @enumFromInt(d_bit);
        const w_flag: word_byte_bit = @enumFromInt(w_bit);

        // Decode operand byte (byte 1)
        const operand_byte = initial_peek[1];
        const mod = operand_byte >> 6;
        const reg = (operand_byte >> 3) & 0b111;
        const rm = operand_byte & 0b111;

        if (rm == 0b110 and mod == 0b00) {
            std.debug.print("DIRECT ACCES MOD", .{});
        }

        const mod_flag: MOD_byte = @enumFromInt(mod);

        // if rm = 0b110 it is direct access and needs a 16bit displacemnt
        // ++ the other 8bit and 16bit memory displacement modes.
        // all this breaks the while loop odd/even else way of walking over the decodes.

        // Determine instruction length based on MOD and R/M
        const instr_len: usize = switch (mod_flag) {
            .register_mode => 2, // Register mode, no displacement
            .memory_8bit_disp_mode => 3, // 8-bit displacement
            .memory_16bit_disp_mode => 4, // 16-bit displacement
            .memory_mode => if (rm == 0b110) 4 else 2, // Direct access = 16-bit disp, otherwise no disp
        };

        // Peek full instruction (for displacement bytes if needed)
        const instruction = reader.interface.peek(instr_len) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        std.debug.print("Got {} bytes\n", .{instruction.len});

        std.debug.print(" | InstrLen: {} bytes.....\n", .{instr_len});

        std.debug.print("OpCode  : {b:0>8}", .{opcode_byte});
        std.debug.print(" -> {t}", .{op_asm});
        std.debug.print(", {t}", .{d_flag});
        std.debug.print(", {t}", .{w_flag});
        std.debug.print(" | Operand: {b:0>8}", .{operand_byte});
        std.debug.print(" -> {t}", .{mod_flag});

        // Use w_bit to decide which register enum to use
        if (w_flag == .word_op) {
            const reg_asm: REG_word = @enumFromInt(reg);
            const rm_asm: REG_word = @enumFromInt(rm);

            // Use d_bit to determine operand order
            if (d_flag == .destination_is_reg) {
                std.debug.print(" {t}, {t}\n", .{ reg_asm, rm_asm });
                try stdout.print("{t} {t}, {t}\n", .{ op_asm, reg_asm, rm_asm });
            } else {
                std.debug.print(" {t}, {t}\n", .{ rm_asm, reg_asm });
                try stdout.print("{t} {t}, {t}\n", .{ op_asm, rm_asm, reg_asm });
            }
        } else {
            const reg_asm: REG_byte = @enumFromInt(reg);
            const rm_asm: REG_byte = @enumFromInt(rm);

            // Use d_bit to determine operand order
            if (d_flag == .destination_is_reg) {
                std.debug.print(" {t}, {t}\n", .{ reg_asm, rm_asm });
                try stdout.print("{t} {t}, {t}\n", .{ op_asm, reg_asm, rm_asm });
            } else {
                std.debug.print(" {t}, {t}\n", .{ rm_asm, reg_asm });
                try stdout.print("{t} {t}, {t}\n", .{ op_asm, rm_asm, reg_asm });
            }
        }

        // Toss the bytes we just processed
        byte_count += instr_len;
        reader.interface.toss(instr_len);
    }
    if (byte_count % 8 != 0) {
        try stdout.writeAll("\n");
    }
    try stdout.flush();
}
