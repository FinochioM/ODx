package cache

import "core:fmt"
import "core:os"
import "core:path/filepath"

get_cache_dir :: proc(allocator := context.allocator) -> string {
    when ODIN_OS == .Windows {
        base := os.get_env("LOCALAPPDATA")
        if base != "" {
            return fmt.aprintf("%s\\odx", base, allocator = allocator)
        }
    } else when ODIN_OS == .Darwin {
        home := os.get_env("HOME")
        if home != "" {
            return fmt.aprintf("%s/Library/Caches/odx", home, allocator = allocator)
        }
    } else {
        xdg := os.get_env("XDG_CACHE_HOME")
        if xdg != "" {
            return fmt.aprintf("%s/odx", xdg, allocator = allocator)
        }
        home := os.get_env("HOME")
        if home != "" {
            return fmt.aprintf("%s/.cache/odx", home, allocator = allocator)
        }
    }

    return ".odx-cache"
}

make_dir_all :: proc(path: string) -> bool {
    if os.exists(path) {
        return true
    }

    parent := filepath.dir(path)
    if parent != path {
        if !make_dir_all(parent) {
            return false
        }
    }

    return os.make_directory(path) == os.ERROR_NONE
}
