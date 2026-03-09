package commands

import "core:fmt"
import "src:module"
import "src:events"

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

collect_nodes :: proc(name: string, task: module.Task, manifest: module.Manifest, out: ^[dynamic]events.Task_Graph_Node) {
    for existing in out^ {
        if existing.name == name do return
    }

    append(out, events.Task_Graph_Node{
        name    = name,
        deps    = task.deps,
        inputs  = task.inputs,
        outputs = task.outputs,
    })

    for dep in task.deps {
        if is_builtin(dep) do continue
        dep_task, found := manifest.tasks[dep]
        if !found do continue
        collect_nodes(dep, dep_task, manifest, out)
    }
}

explain_task :: proc(name: string, task: module.Task, manifest: module.Manifest) {
    if events.is_enabled() {
        nodes := make([dynamic]events.Task_Graph_Node)
        defer delete(nodes)
        collect_nodes(name, task, manifest, &nodes)
        events.emit(events.Task_Graph{
            event = "task_graph",
            root  = name,
            nodes = nodes[:],
        })
        return
    }

    fmt.printfln("task graph for: %s", name)
    print_task_graph(name, task, manifest, 1)
}

explain_build :: proc(profile: string, target: string, manifest: module.Manifest) {
    if events.is_enabled() {
        nodes := make([dynamic]events.Task_Graph_Node)
        defer delete(nodes)

        deps := make([dynamic]string)
        defer delete(deps)
        for hook in manifest.build.pre_build {
            append(&deps, hook)
        }
        append(&deps, "compile")

        append(&nodes, events.Task_Graph_Node{
            name = "build",
            deps = deps[:],
        })

        for hook in manifest.build.pre_build {
            name := hook[len("tasks."):] if len(hook) > 6 && hook[:6] == "tasks." else hook
            task, found := manifest.tasks[name]
            if found {
                collect_nodes(hook, task, manifest, &nodes)
            }
        }

        events.emit(events.Task_Graph{
            event = "task_graph",
            root  = "build",
            nodes = nodes[:],
        })
        return
    }

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
