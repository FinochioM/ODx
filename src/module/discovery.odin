package module

import "core:fmt"
import "core:os"
import "core:path/filepath"

Module :: struct {
    root:           string,
    name:           string,
    has_manifest:   bool,  
}

resolve :: proc(start: string, allocator := context.allocator) -> (Module, bool) {
    abs, ok := filepath.abs(start, allocator)
    if !ok {
        fmt.eprintfln("odx: could not resolve path '%s'", start)
        return {}, false
    }

    fi, stat_err := os.stat(abs, allocator)
    if stat_err != os.ERROR_NONE {
        fmt.eprintfln("odx: path does not exist: '%s'", abs)
        return {}, false
    }

    search_dir := abs
    if !fi.is_dir {
        search_dir = filepath.dir(abs, allocator)
    }

    dir := search_dir

    for {
        manifest := filepath.join({dir, "odx.toml"}, allocator)
        if os.exists(manifest) {
            return Module{
                root        =   dir,
                name        =   filepath.base(dir),
                has_manifest =  true,
            }, true
        }

        parent := filepath.dir(dir, allocator)
        if parent == dir {
            // filesystem root 
            break
        }

        dir = parent
    }

    return Module {
        root        =   search_dir,
        name        =   filepath.base(search_dir),
        has_manifest =  false,
    }, true
}
