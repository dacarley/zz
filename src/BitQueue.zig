const std = @import("std");

const Self = @This();

data: usize = 0,
len: u8 = 0,

pub fn enqueue(self: *Self, b: u1) void {
    std.debug.assert(self.len < @bitSizeOf(usize));

    self.data <<= 1;
    self.len += 1;

    if (b == 1) {
        self.data |= 1;
    } else {
        self.data &= ~@as(usize, 1);
    }
}

pub fn deque(self: *Self) u1 {
    std.debug.assert(self.len >= 1);

    defer self.len -= 1;

    return @truncate((self.data >> @truncate(self.len - 1)) & 1);
}
