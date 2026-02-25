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
        case:
            fmt.eprintln("Unknown command")
            os.exit(1)
    }
}
