package commands

import "core:fmt"
import "src:module"

print_task_graph :: proc(name: string, task: module.Task, manifest: module.Manifest, indent: int) {
    prefix := ""
    for i in 0..<indent {
        prefix = fmt.aprintf("%s  ", prefix)
    }

    fmt.printfln("%s%s", prefix, name)

    if len(task.inputs) > 0 {
        fmt.printfln("%s  inputs:  %v", prefix, task.inputs)
    }
    if len(task.outputs) > 0 {
        fmt.printfln("%s  outputs: %v", prefix, task.outputs)
    }

    for dep in task.deps {
        if is_builtin(dep) {
            fmt.printfln("%s  [builtin] %s", prefix, dep)
            continue
        }
        dep_task, found := manifest.tasks[dep]
        if !found {
            fmt.printfln("%s  [unknown] %s", prefix, dep)
            continue
        }
        print_task_graph(dep, dep_task, manifest, indent + 1)
    }
}

explain_task :: proc(name: string, task: module.Task, manifest: module.Manifest) {
    fmt.printfln("task graph for: %s", name)
    print_task_graph(name, task, manifest, 1)
}

explain_build :: proc(profile: string, target: string, manifest: module.Manifest) {
    fmt.printfln("task graph for: build")
    fmt.printfln("  build")
    fmt.printfln("    profile: %s", profile)
    fmt.printfln("    target:  %s", target)

    if len(manifest.build.pre_build) > 0 {
        fmt.printfln("    pre_build:")
        for hook in manifest.build.pre_build {
            name := hook[len("tasks."):] if len(hook) > 6 && hook[:6] == "tasks." else hook
            task, found := manifest.tasks[name]
            if found {
                print_task_graph(hook, task, manifest, 3)
            } else {
                fmt.printfln("      %s", hook)
            }
        }
    }

    fmt.printfln("    compile")
}
