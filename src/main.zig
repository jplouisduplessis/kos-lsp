const std = @import("std");
const encoder = @import("lsp.zig");
const messages = @import("messages.zig");
pub fn main() !void {

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();
    //
    // try stdout.print("Run `zig build test` to run the tests.\n", .{});
    //
    // try bw.flush(); // don't forget to flucontentTypesh!
    // f
    // Loop until exit recieved

    const allocator = std.heap.page_allocator;
    var string = std.ArrayList(u8).init(allocator);
    defer string.deinit();
    // const stdout_file = std.io.getStdOut().writer();
    const stdin_file = std.io.getStdIn().reader();
    // var bw = std.io.bufferedWriter(stdout_file);
    // var br = std.io.bufferedReader(stdin_file);
    std.log.info("Started KSP OS Language Server Protocol\n", .{});
    std.log.info("Waiting for requests...\n", .{});
    var buffer: [1024]u8 = undefined;
    while (true) {
        const extracted = try stdin_file.readUntilDelimiterOrEof(&buffer, '\n');
        if (extracted == null) {
            continue;
        }
        // Read message from client
        std.log.debug("KSP LSP - Received from stream\n{s}\n", .{extracted.?});

        //Try content header.
        var segmentIterator = std.mem.splitSequence(u8, extracted.?, "\r\n");
        const trimChars = [_]u8{ ' ', '\n', '\r' };
        var contentLength: u64 = 0;
        while (segmentIterator.next()) |seg| {
            const lengthIndex = std.mem.indexOf(u8, seg, ":");
            if (lengthIndex == null) {
                std.log.err("KSP LSP - Received malformed content header\n", .{});
                break;
            }
            const headerKey = std.mem.trim(u8, seg[0..lengthIndex.?], &trimChars);
            const headerValue = std.mem.trim(u8, seg[lengthIndex.? + 1 ..], &trimChars);
            std.log.debug("KSP LSP - Found header [{s}:{s}]\n", .{ headerKey, headerValue });
            if (std.mem.eql(u8, headerKey, "Content-Length")) {
                contentLength = std.fmt.parseInt(u64, headerValue, 0) catch 0;
            }
        }
        if (contentLength == 0) {
            //Might be in the middle of some other message. Continue reading
            std.log.debug("KSP LSP - No header found. Continuing\n", .{});
            continue;
        }

        //Create buffer to hold the expected bytes
        //If we have a content header, move to content and try read. Keep waiting for bytes until enought received
        const content = try stdin_file.readAllAlloc(allocator, contentLength);
        defer allocator.free(content);
        // var decodedMsg = try encoder.decodeMessage(string.items);
        // defer decodedMsg.deinit();
        std.log.info("KSP LSP - Content Recieved: {s}\n", .{content});
    }
}
