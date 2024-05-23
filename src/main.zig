const std = @import("std");
const BitBuffer = @import("./BitBuffer.zig");
const BitQueue = @import("./BitQueue.zig");

const Node = struct {
    value: ?u8 = null,
    left: ?*const Node = null,
    right: ?*const Node = null,

    weight: usize = 0,
};

const Weight = struct {
    value: u8 = 0,
    weight: usize = 0,
};

const EncodedResult = struct {
    original_len: usize,
    weights: []const Weight,
    data: []const u8,
};

fn ltNodePQ(_: void, a: *const Node, b: *const Node) std.math.Order {
    return if (a.weight > b.weight) std.math.Order.gt else std.math.Order.lt;
}

fn ltSortWeight(_: void, a: Weight, b: Weight) bool {
    return a.weight < b.weight;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const data = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?";

    const encoded = try encode(allocator, data);
    std.debug.print("Result: {any} -> {any}\n", .{ data.len, encoded.data.len });

    const decoded = try decode(allocator, encoded);
    std.debug.print("{s}\n", .{decoded});
}

fn encode(allocator: std.mem.Allocator, data: []const u8) !EncodedResult {
    const weights = try getWeights(allocator, data);
    const tree = try buildTree(allocator, weights);
    // TODO: Figure out deinit for the tree

    var leafBits = [_]BitQueue{.{}} ** 256;
    getLeafBits(&leafBits, tree, .{});

    var bit_buffer = try BitBuffer.init(allocator);
    defer bit_buffer.deinit();
    for (data) |b| {
        try bit_buffer.push(leafBits[b]);
    }

    // TODO: What needs to be released?
    return .{
        .original_len = data.len,
        .weights = weights,
        .data = try bit_buffer.toOwnedSlice(),
    };
}

fn getLeafBits(leafBits: *[256]BitQueue, nullableNode: ?*const Node, bits: BitQueue) void {
    if (nullableNode) |node| {
        if (node.value) |value| {
            leafBits[value] = bits;
        } else {
            var left_bits = bits;
            left_bits.enqueue(0);
            getLeafBits(leafBits, node.left, left_bits);

            var right_bits = bits;
            right_bits.enqueue(1);
            getLeafBits(leafBits, node.right, right_bits);
        }
    }
}

fn getWeights(allocator: std.mem.Allocator, data: []const u8) ![]const Weight {
    var weights = try allocator.alloc(Weight, 256);
    for (0..256) |i| {
        weights[i] = .{
            .value = @truncate(i),
            .weight = 0,
        };
    }

    for (data) |b| {
        weights[b].weight += 1;
    }

    std.sort.insertion(Weight, weights, {}, ltSortWeight);

    var index: usize = 0;
    while (weights[index].weight == 0) {
        index += 1;
    }

    return weights[(index - 1)..256];
}

fn buildTree(allocator: std.mem.Allocator, weights: []const Weight) !*const Node {
    var pq = std.PriorityQueue(*const Node, void, ltNodePQ).init(allocator, {});
    defer pq.deinit();

    for (weights) |w| {
        const node = try allocator.create(Node);
        errdefer allocator.destroy(node);
        node.* = .{
            .value = w.value,
            .weight = w.weight,
        };

        try pq.add(node);
    }

    while (pq.len > 1) {
        const left = pq.remove();
        const right = pq.remove();

        const node = try allocator.create(Node);
        errdefer allocator.destroy(node);
        node.* = .{
            .left = left,
            .right = right,
            .weight = left.weight + right.weight,
        };

        try pq.add(node);
    }

    return pq.remove();
}

fn decode(allocator: std.mem.Allocator, encoded: EncodedResult) ![]const u8 {
    const decompressed = try allocator.alloc(u8, encoded.original_len);
    errdefer allocator.free(decompressed);

    const tree = try buildTree(allocator, encoded.weights);

    var i: usize = 0;
    var bit_index: usize = 0;
    var curr_node: ?*const Node = tree;
    while (i < encoded.original_len) : (i += 1) {
        while (curr_node.?.value == null) : (bit_index += 1) {
            const byte_index = bit_index / 8;
            const shift: u3 = @truncate(bit_index % 8);

            const bit = (encoded.data[byte_index] >> shift) & 1;
            curr_node = if (bit == 0) curr_node.?.left else curr_node.?.right;
        }

        decompressed[i] = curr_node.?.value.?;

        curr_node = tree;
    }

    return decompressed;
}
