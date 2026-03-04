package commands

import "core:fmt"
import "core:strings"
import "src:module"

run_hooks :: proc(hooks: []string, mod: module.Module, manifest: module.Manifest, verbose: bool) -> bool {
    for hook in hooks {
        name := hook
        if strings.has_prefix(hook, "tasks.") {
            name = hook[len("tasks."):]
        }

        task, found := manifest.tasks[name]
        if !found {
            fmt.eprintfln("odx: hook '%s' references unknown task '%s'", hook, name)
            return false
        }

        if verbose {
            fmt.printfln("odx: running hook '%s'", hook)
        }

        if !exec_task(name, task, mod, manifest, verbose, nil, false) {
            fmt.eprintfln("odx: hook '%s' failed, aborting", hook)
            return false
        }
    }
    return true
}
