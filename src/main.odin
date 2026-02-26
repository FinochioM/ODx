package main

import "core:fmt"
import "core:os"
import "src:cli"
import "src:commands"

main :: proc() {
    args := cli.parse(os.args[1:])
    
    #partial switch args.command {
        case .Doctor:
            commands.doctor()
        case .List:
            commands.list(args.path)
        case .Build:
            if !commands.build({
                path = args.path,
                profile = args.profile,
                target = args.target,
                out = args.out,
                verbose = args.verbose,
                no_cache = args.no_cache,
            }) {
                os.exit(1)
            }
        case .Run:
            if !commands.run({
                path = args.path,
                profile = args.profile,
                target = args.target,
                verbose = args.verbose,
                run_args = args.raw_args,
            }) {
                os.exit(1)
            }
        case .Clean:
            if !commands.clean({
                path = args.path,
                all = args.clean_all,
                verbose = args.verbose,
            }) {
                os.exit(1)
            }
        case .Check:
            if !commands.check({
                path = args.path,
                profile = args.profile,
                target = args.target,
                verbose = args.verbose,
            }) {
                os.exit(1)
            }
        case .Test:
            if !commands.test({
                path = args.path,
                profile = args.profile,
                target = args.target,
                verbose = args.verbose,
            }) {
                os.exit(1)
            }
        case .Task:
            if !commands.run_task({
                path = args.path,
                task_name = args.task_name,
                verbose = args.verbose,
                run_args = args.raw_args,
            }) {
                os.exit(1)
            }
        case:
            fmt.eprintln("Unknown command")
            os.exit(1)
    }
}
