package commands

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:strings"

ODX_VERSION :: "0.1.0-dev"

doctor :: proc() {
    fmt.println("odx", ODX_VERSION)

    odin_version := get_tool_version("odin", "version")
    defer delete(odin_version)
    fmt.println("odin:", odin_version)

    cache_dir := get_cache_dir()
    defer delete(cache_dir)
    fmt.println("cache:", cache_dir)
}

@(private)
get_tool_version :: proc(tool, subcmd: string) -> string {
    _, stdout, _, err := os2.process_exec({ command = []string{tool, subcmd}}, context.allocator)

    if err != nil {
        return strings.clone("(not found)")
    }

    result := strings.trim_space(string(stdout))
    return strings.clone(result)
}

@(private)
get_cache_dir :: proc() -> string {
    when ODIN_OS == .Windows {
        base := os.get_env("LOCALAPPDATA")
        if base != "" {
            return fmt.aprintf("%s\\odx", base)
        }

        return strings.clone(".odx-cache")
    } else when ODIN_OS == .Darwin {
        home = os.get_env("HOME")
        if home != "" {
            return fmt.aprintf("%s/Library/Caches/odx", home)
        }

        return strings.clone(".odx-cache")
    } else {
        xdg := os.get_env("XDG_CACHE_HOME")
        if xdg != "" {
            return fmt.aprintf("%s/odx", xdg)
        }

        home := os.get_env("HOME")
        if home != "" {
            return fmt.aprintf("%s/.cache/odx", home)
        }

        return strings.clone(".odx-cache")
    }
}
