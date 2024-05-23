const std = @import("std");
const BitQueue = @import("./BitQueue.zig");

const Self = @This();

buffer: std.ArrayList(u8),
len: u32 = 0,

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .buffer = std.ArrayList(u8).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.buffer.deinit();
}

pub fn push(self: *Self, bits: BitQueue) !void {
    const cur_num_bytes = (self.len + 7) / 8;
    const new_num_bytes = (self.len + bits.len + 7) / 8;
    try self.buffer.appendNTimes(0, new_num_bytes - cur_num_bytes);

    var mutBits = bits;

    while (mutBits.len > 0) {
        const byte_index = self.len / 8;
        var byte = self.buffer.items[byte_index];

        const bit = mutBits.deque();
        const shift: u3 = @truncate(self.len % 8);
        const mask = @as(u8, 1) << shift;

        if (bit == 1) {
            byte |= mask;
        } else {
            byte &= ~mask;
        }

        self.buffer.items[byte_index] = byte;

        self.len += 1;
    }
}

pub fn toOwnedSlice(self: *Self) ![]u8 {
    return self.buffer.toOwnedSlice();
}

pub fn getBit(self: *Self, bit_index: u32) bool {
    const byte_index = bit_index / 8;
    const shift: u3 = @truncate(bit_index % 8);

    return (self.buffer.items[byte_index] >> shift) & 1 == 1;
}

pub fn len(self: *Self) usize {
    return self.buffer.items.len;
}
