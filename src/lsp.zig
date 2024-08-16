const std = @import("std");
/// Base type to extract message info from
pub const RpcMessage = struct {
    contentLength: u64 = 0,
    contentType: []const u8 = undefined,
    content: []const u8 = undefined,
    allocator: std.mem.Allocator,
    pub fn getInfo(self: RpcMessage) !RpcContentInfo {
        const result = std.json.parseFromSlice(RpcContentInfo, self.allocator, self.content, .{}) catch |err|
            {
            std.log.err("Encountered json parsing error: {}\n", .{err});
            return EncoderError.InvalidJson;
        };
        defer result.deinit();
        errdefer self.allocator.free(result);
        return result.value;
    }
    ///Release memory used by this object internally
    pub fn deinit(_: RpcMessage) void {}
};
pub const RpcContentInfo = struct { jsonrpc: []const u8 = undefined, id: u64 = 0, method: []const u8 = undefined };

pub const EncoderError = error{ MalformedHeader, NoContent, NoHeader, InvalidJson, Undefined };
/// Used to extract all header entries in the provided content
pub fn decodeMessage(msg: []const u8) !RpcMessage {
    var rpcMessage = RpcMessage{ .allocator = std.heap.page_allocator };
    var segmentIterator = std.mem.splitSequence(u8, msg, "\r\n");
    const trimChars = [_]u8{ ' ', '\n', '\r' };
    while (segmentIterator.next()) |seg| {
        if (seg.len == 0) {
            std.log.debug("Reached end of header section\n", .{});
            const content = segmentIterator.next().?;
            rpcMessage.content = content;
            return rpcMessage;
        }
        const lengthIndex = std.mem.indexOf(u8, seg, ":");
        if (lengthIndex == null) {
            std.log.err("Received malformed content header\n", .{});
            return EncoderError.MalformedHeader;
        }
        const headerKey = std.mem.trim(u8, seg[0..lengthIndex.?], &trimChars);
        const headerValue = std.mem.trim(u8, seg[lengthIndex.? + 1 ..], &trimChars);
        std.log.debug("Found header [{s}:{s}]\n", .{ headerKey, headerValue });
        if (std.mem.eql(u8, headerKey, "Content-Length")) {
            rpcMessage.contentLength = std.fmt.parseInt(u64, headerValue, 0) catch 0;
        } else if (std.mem.eql(u8, headerKey, "Content-Type")) {
            rpcMessage.contentType = headerValue;
        } else {
            std.log.warn("Skipping header [{s}:{s}]\n", .{ headerKey, headerValue });
        }
    }
    return rpcMessage;
}
pub fn encodeMessage(comptime msg: anytype) ![]const u8 {
    // var buf: [128:0]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buf);
    // const byte = try allocator.alloc(u8, 1024);
    // defer allocator.free(byte);
    // Add header stuff
    const allocator = std.heap.page_allocator;
    var string = std.ArrayList(u8).init(allocator);
    // defer string.deinit();
    try std.json.stringify(msg, .{}, string.writer());
    return string.items;
}

const testing = std.testing;
test "can decode message" {
    std.debug.print("\nRUNNING TEST - 'can parse message\n", .{});
    const content =
        \\{"jsonrpc" : "2.0","id": 1,
        \\"method" : "textDocument/completion"}
    ;
    const msg = "Content-Length :  10\r\nContent-Type: foo\r\nSome-Header:val\r\n\r\n" ++ content;
    var output = try decodeMessage(msg);

    defer output.deinit();
    //Check received headers
    try testing.expect(std.mem.eql(u8, "foo", output.contentType));
    try testing.expect(10 == output.contentLength);
    try testing.expect(std.mem.eql(u8, content, output.content));
}
test "can retrieve info" {
    std.debug.print("\nRUNNING TEST - can retrieve info\n", .{});
    const content =
        \\{"jsonrpc" : "2.0","id": 1,
        \\"method" : "textDocument/completion"}
    ;
    const parsed = RpcMessage{ .allocator = testing.allocator, .content = content, .contentType = "textDocument/completion", .contentLength = 10 };
    const output = try parsed.getInfo();
    std.debug.print("Method: {s},Version: {s}", .{ output.method, output.jsonrpc });
    try testing.expect(std.mem.eql(u8, "textDocument/completion", output.method));
}
test "can encode msg" {
    std.debug.print("\nRUNNING TEST - can encode msg\n");

    // const content =
    //     \\{"jsonrpc" : "2.0","id": 1,
    //     \\"method" : "textDocument/completion"}
    // ;
    // const msg = "Content-Length :  10\r\nContent-Type: foo\r\nSome-Header:val\r\n\r\n" ++ content;
    // _ = encodeMessage(RpcContentInfo{});
}
