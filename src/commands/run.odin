package commands

import "core:fmt"
import "core:os/os2"

Run_Args :: struct {
    path:       string,
    profile:    string,
    target:     string,
    verbose:    bool,
    run_args:   []string,
}

run :: proc(a: Run_Args) -> bool {
    bin_path, ok := build_binary({
        path = a.path,
        profile = a.profile,
        target = a.target,
        verbose = a.verbose,
    })

    if !ok do return false

    argv := make([dynamic]string)
    defer delete(argv)

    append(&argv, bin_path)
    for arg in a.run_args {
        append(&argv, arg)
    }

    if a.verbose {
        fmt.println("running:", bin_path)
    }

    state, _, _, run_err := os2.process_exec({command = argv[:]}, context.allocator)
    if run_err != nil {
        fmt.eprintfln("odx: failed to launch binary: %v", run_err)
        return false
    }

    if state.exit_code != 0 {
        fmt.eprintfln("odx: program exited with code %d", state.exit_code)
        return false
    }

    return true
}
