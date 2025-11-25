const std = @import("std");

// Объявляем типы как opaque - избегаем проблем с cImport
pub const ptls_t = opaque {};
pub const ptls_context_t = opaque {};
pub const ptls_cipher_suite_t = opaque {};

pub const ptls_buffer_t = extern struct {
    base: [*]u8,
    capacity: usize,
    off: usize,
    is_allocated: c_int,
};

// Внешние функции picotls
extern fn ptls_buffer_init(buf: *ptls_buffer_t, smallbuf: [*]const u8, smallbuf_size: usize) void;
extern fn ptls_buffer_dispose(buf: *ptls_buffer_t) void;
extern fn ptls_new(ctx: *ptls_context_t, is_server: c_int) ?*ptls_t;
extern fn ptls_free(tls: *ptls_t) void;
extern fn ptls_handshake(tls: *ptls_t, sendbuf: *ptls_buffer_t, input: ?*const anyopaque, inlen: *usize, properties: ?*anyopaque) c_int;
extern fn ptls_send(tls: *ptls_t, sendbuf: *ptls_buffer_t, input: *const anyopaque, inlen: usize) c_int;
extern fn ptls_receive(tls: *ptls_t, decryptbuf: *ptls_buffer_t, input: *const anyopaque, inlen: *usize) c_int;
extern fn ptls_is_server(tls: *ptls_t) c_int;
extern fn ptls_get_server_name(tls: *ptls_t) ?[*:0]const u8;
extern fn ptls_set_server_name(tls: *ptls_t, name: [*:0]const u8, len: usize) c_int;
extern fn ptls_get_cipher(tls: *ptls_t) ?*const ptls_cipher_suite_t;

// C API exports
export fn tls_buffer_init(buf: *ptls_buffer_t) void {
    ptls_buffer_init(buf, "", 0);
}

export fn tls_buffer_dispose(buf: *ptls_buffer_t) void {
    ptls_buffer_dispose(buf);
}

export fn tls_buffer_data(buf: *ptls_buffer_t) [*]const u8 {
    return buf.base;
}

export fn tls_buffer_len(buf: *ptls_buffer_t) usize {
    return buf.off;
}

export fn tls_new(ctx: *ptls_context_t, is_server: c_int) ?*ptls_t {
    return ptls_new(ctx, is_server);
}

export fn tls_free(tls: *ptls_t) void {
    ptls_free(tls);
}

export fn tls_handshake(tls: *ptls_t, sendbuf: *ptls_buffer_t, input: ?[*]const u8, input_len: *usize) c_int {
    const ptr: ?*const anyopaque = if (input) |i| @ptrCast(i) else null;
    return ptls_handshake(tls, sendbuf, ptr, input_len, null);
}

export fn tls_send(tls: *ptls_t, sendbuf: *ptls_buffer_t, plaintext: [*]const u8, len: usize) c_int {
    return ptls_send(tls, sendbuf, plaintext, len);
}

export fn tls_receive(tls: *ptls_t, decryptbuf: *ptls_buffer_t, input: [*]const u8, input_len: *usize) c_int {
    return ptls_receive(tls, decryptbuf, input, input_len);
}

export fn tls_is_server(tls: *ptls_t) c_int {
    return ptls_is_server(tls);
}

export fn tls_get_server_name(tls: *ptls_t) ?[*:0]const u8 {
    return ptls_get_server_name(tls);
}

export fn tls_set_server_name(tls: *ptls_t, name: [*:0]const u8) c_int {
    return ptls_set_server_name(tls, name, 0);
}

export fn tls_get_cipher(tls: *ptls_t) ?*const anyopaque {
    return ptls_get_cipher(tls);
}
