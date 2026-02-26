package cache

import "core:fmt"
import "core:hash"
import "core:strings"

hash_bytes :: proc(data: []byte, allocator := context.allocator) -> string {
    h := hash.fnv64a(data)
    return fmt.aprintf("%016x", h, allocator = allocator)
}

hash_string :: proc(s: string, allocator := context.allocator) -> string {
    return hash_bytes(transmute([]byte)s, allocator)
}

@(private)
bytes_to_hex :: proc(data: []byte, allocator := context.allocator) -> string {
    sb := strings.builder_make(len(data) * 2, allocator)
    for b in data {
        fmt.sbprintf(&sb, "%02x", b)
    }
    return strings.to_string(sb)
}
