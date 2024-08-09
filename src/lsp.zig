const std = @import("std");
/// Base type to extract message info from
pub const RpcMessage = struct {
    contentLength: u64 = 0,
    contentType: []const u8 = undefined,
    content: []const u8 = undefined,
    ///Release memory used by this object internally
    pub fn deinit(_: RpcMessage) void {}
};
pub const RpcContentInfo = struct { jsonrpc: []const u8, id: u64, method: []const u8, params: []const u8 };

pub const EncoderError = error{ MalformedHeader, NoContent, NoHeader, InvalidJson, Undefined };
/// Used to extract all header entries in the provided content
// fn extractHeaders(msg: []const u8) !std.StringHashMap([]const u8) {
fn parseMessage(msg: []const u8) !RpcMessage {
    var rpcMessage = RpcMessage{};
    // const allocator = std.heap.page_allocator;
    var segmentIterator = std.mem.splitSequence(u8, msg, "\r\n");
    // var headerList = std.StringHashMap([]const u8).init(allocator);

    const trimChars = [_]u8{ ' ', '\n', '\r' };
    // defer headerList.deinit();
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
    const allocator = std.heap.page_allocator;
    var string = std.ArrayList(u8).init(allocator);
    // defer string.deinit();
    try std.json.stringify(msg, .{}, string.writer());
    return string.items;
}
//TODO: Combine with extractHeaders  for efficiency

pub fn decodeMessage(content: []const u8) EncoderError!RpcMessage {
    //Try to get header
    const rpcHeader = "Content-Length";
    const trimChars = [_]u8{ ' ', '\n', '\r' };
    var contentLength: u64 = 0;
    var headerEnd: u64 = 0;

    const arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    //HACK: Surely there muse be a simpler way
    //TODO: Split into array on newlines
    if (std.mem.indexOf(u8, content, rpcHeader)) |headerStart| {
        std.debug.print("Found Content-Header at {x}\n", .{headerStart});
        if (std.mem.indexOf(u8, content[headerStart..], ":")) |headerDiv| {
            const headerLength: u16 = @intCast(headerStart + headerDiv);
            if (std.mem.indexOf(u8, content, "\r\n")) |end| {
                std.debug.print("Located end of line at {}\n", .{end});

                headerEnd = headerLength + end + 1;
                const lengthString = std.mem.trim(u8, content[headerLength + 1 .. headerEnd], &trimChars);

                std.debug.print("Located length:{s}\n", .{lengthString});
                contentLength = std.fmt.parseInt(u64, lengthString, 0) catch 10;
                std.debug.print("Found content with length {}\n", .{contentLength});
                if (contentLength <= 0) {
                    return EncoderError.NoContent;
                }
            } else {
                return EncoderError.NoContent;
            }
        }
        //Try to get content length
    } else {
        return EncoderError.NoHeader;
    }
    //
    // //Find json content start
    // if (std.mem.indexOf(u8, content[headerEnd..], "{")) |jsonStart| {
    //     const allocator = std.heap.page_allocator;
    //     std.debug.print("Found start of JSON at {}", .{jsonStart + headerEnd});
    //     //Try marshal json object to provided type
    //     const parsed = std.json.parseFromSlice(RpcMessage, allocator, content[headerEnd + jsonStart ..], .{}) catch |err| {
    //         std.debug.print("Error encountered parsing to json. {}\n", .{err});
    //         return EncoderError.InvalidJson;
    //     };
    //     return parsed.value;
    // }
    return EncoderError.Undefined;
}
const testing = std.testing;
test "can parse message" {
    std.debug.print("\nRUNNING TEST - 'can parse message\n", .{});
    const content =
        \\{"jsonrpc" : "2.0","id": 1,
        \\"method" : "textDocument/completion"}
    ;
    const msg = "Content-Length :  10\r\nContent-Type: foo\r\nSome-Header:val\r\n\r\n" ++ content;
    var output = try parseMessage(msg);

    defer output.deinit();
    //Check received headers
    try testing.expect(std.mem.eql(u8, "foo", output.contentType));
    try testing.expect(10 == output.contentLength);
    try testing.expect(std.mem.eql(u8, content, output.content));
    std.debug.print("\nTEST PASSED - 'can parse message'\n", .{});
}
