package module

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

resolve_entry :: proc(mod: Module, manifest: Manifest, has_manifest: bool, allocator := context.allocator) -> (entry: string, ok: bool) {
    if has_manifest {
        path := filepath.join({mod.root, manifest.root}, allocator)
        if !os.exists(path) {
            fmt.eprintfln("odx: source root does not exist: '%s'", path)
            return "", false
        }

        return path, true
    }

    src_main := filepath.join({mod.root, "src", "main.odin"}, allocator)
    if os.exists(src_main) {
        return filepath.join({mod.root, "src"}, allocator), true
    }

    root_main := filepath.join({mod.root, "main.odin"}, allocator)
    if os.exists(root_main) {
        return strings.clone(mod.root, allocator), true
    }

    fmt.eprintfln("odx: could not find an entry point in '%s'", mod.root)
    fmt.eprintfln(" hint: create src/main.odin or main.odin, or add [project] root = \"...\" to odx.toml")
    return "", false
}
