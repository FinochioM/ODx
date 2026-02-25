package commands

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "src:module"

Clean_Args :: struct {
    path:       string,
    all:        bool,
    verbose:    bool,
}

clean :: proc(a: Clean_Args) -> bool {
    mod, ok := module.resolve(a.path)
    if !ok do return false

    out_dir := "build"

    if mod.has_manifest {
        manifest_path := filepath.join({mod.root, "odx.toml"})
        if m, mok := module.load_manifest(manifest_path); mok {
            if m.out_dir != "" {
                out_dir = m.out_dir
            }
        }
    }

    build_dir := filepath.join({mod.root, out_dir})

    if os.exists(build_dir) {
        if a.verbose {
            fmt.printfln("odx: removing %s", build_dir)
        }

        if !remove_dir_all(build_dir) {
            fmt.eprintfln("odx: failed to remove '%s'", build_dir)
            return false
        }
        fmt.printfln("odx: cleaned %s", build_dir)
    } else {
        fmt.printfln("odx: nothing to clean")
    }

    return true
}

@(private)
remove_dir_all :: proc(path: string) -> bool {
    fd, err := os.open(path)
    if err != os.ERROR_NONE do return false
    defer os.close(fd)

    entries, read_err := os.read_dir(fd, -1, context.allocator)
    if read_err != os.ERROR_NONE do return false
    defer os.file_info_slice_delete(entries, context.allocator)

    for entry in entries {
        if entry.is_dir {
            if !remove_dir_all(entry.fullpath) do return false
        } else {
            if os.remove(entry.fullpath) != os.ERROR_NONE do return false
        }
    }

    return os.remove_directory(path) == os.ERROR_NONE
}
