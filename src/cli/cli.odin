package cli

import "core:fmt"
import "core:os"

Command :: enum {
    Run,
    Build,
    Test,
    Fmt,
    Check,
    Clean,
    Task,
    List,
    Doctor,
}

Args :: struct {
    command     : Command,
    path        : string,
    verbose     : bool,
    quiet       : bool,
    no_cache    : bool,

    raw_args    : []string,
}

parse :: proc(argv: []string) -> Args {
    if len(argv) == 0 {
        print_usage()
        os.exit(0)
    }

    args: Args
    args.path = "."

    switch argv[0] {
        case "run":     args.command = .Run
        case "build":   args.command = .Build
        case "test":    args.command = .Test
        case "fmt":     args.command = .Fmt
        case "check":   args.command = .Check
        case "clean":   args.command = .Clean
        case "task":    args.command = .Task
        case "list":    args.command = .List
        case "doctor":  args.command = .Doctor
        case:
            fmt.eprintfln("odx: unknown command '%s'", argv[0])
            os.exit(1)
    }

    rest := argv[1:]
    for i := 0; i < len(rest); i += 1 {
        switch rest[i] {
            case "-v", "--verbose": args.verbose = true
            case "-q", "--quiet": args.quiet = true
            case "--no-cache": args.no_cache = true
            case "--":
                args.raw_args = rest[i + 1:]
                break
            case:
                if len(rest[i]) > 0 && rest[i][0] != '-' {
                    args.path = rest[i]
                }
        }
    }

    return args
}

@(private)
print_usage :: proc() {
    fmt.println(
        `Usage: odx <command> [path] [flags]

        Commands:
            run     Build and run
            build   Build only
            test    Run tests
            fmt     Format source
            check   Type-check only
            clean   Remove build outputs
            task    Run a named task
            list    List modules and tasks
            doctor  Show environment info`
        )
}
