package module

import "core:os"
import "core:path/filepath"
import "core:strings"

EXCLUDED_DIRS :: []string{"build", ".git", ".odx", ".cache", "vendor"}

collect_sources :: proc(root: string, allocator := context.allocator) -> ([]string, bool) {
    sources := make([dynamic]string, allocator)

    err := walk(root, root, &sources, allocator)
    if err != os.ERROR_NONE {
        delete(sources)
        return nil, false
    }

    return sources[:], true
}

@(private)
walk :: proc(root, dir: string, out: ^[dynamic]string, allocator := context.allocator) -> os.Errno {
    fd, err := os.open(dir)
    if err != os.ERROR_NONE {
        return err
    }

    defer os.close(fd)

    entries, read_err := os.read_dir(fd, -1, allocator)
    if read_err != os.ERROR_NONE {
        return read_err
    }

    defer os.file_info_slice_delete(entries, allocator)

    for entry in entries {
        if entry.is_dir {
            if is_excluded(entry.name) {
                continue
            }

            walk(root, entry.fullpath, out, allocator)
        } else if strings.has_suffix(entry.name, ".odin") {
            append(out, strings.clone(entry.fullpath, allocator))
        }
    }

    return os.ERROR_NONE
}

@(private)
is_excluded :: proc(name: string) -> bool {
    for dir in EXCLUDED_DIRS {
        if name == dir {
            return true
        }
    }

    return false
}
