package main

import "core:fmt"
import "core:os"
import "cli"
import "commands"

main :: proc() {
    args := cli.parse(os.args[1:])
    
    #partial switch args.command {
        case .Doctor:
            commands.doctor()
        case:
            fmt.eprintln("Unknown command")
            os.exit(1)
    }
}
