package commands

import "core:fmt"
import "core:os/os2"
import "core:strings"
import "src:cache"
import "src:version"

doctor :: proc() {
    fmt.println("odx", version.ODX_VERSION)

    odin_ver := get_odin_version()
    defer delete(odin_ver)
    fmt.println("odin:", odin_ver)

    cache_dir := cache.get_cache_dir()
    defer delete(cache_dir)
    fmt.println("cache:", cache_dir)
}

get_odin_version :: proc(allocator := context.allocator) -> string {
    _, stdout, _, err := os2.process_exec(
        {command = []string{"odin", "version"}},
        context.allocator,
    )
    if err != nil {
        return strings.clone("(not found)", allocator)
    }
    return strings.clone(strings.trim_space(string(stdout)), allocator)
}
