# Brainfuck Interpreter & Code Generator (Bash)

[ English Version | [简体中文](README_zh.md) ]

![](usage-screenshot.png)
![](demo-screenshot.png)

A **pure Bash** implementation of the classic [Brainfuck](https://en.wikipedia.org/wiki/Brainfuck) language, featuring:

- A fully compliant interpreter with **8‑bit wrapping cells**, **unbounded bidirectional tape**, and proper bracket matching.
- A **Brainfuck code generator** that compiles any ASCII string into a compact BF program.
- An **interactive REPL** with special commands for testing and scripting.
- Command‑line options for file/string execution, code generation, and version info.

The interpreter follows Urban Müller’s original 1993 semantics, including `,` returning 0 on EOF and `+`/`-` wrapping at 255.

---

## Features

- **Standard 8 commands**: `> < + - . , [ ]` – exactly as defined in the original.
- **Tape**: Automatically expands in 128‑cell blocks in both directions (no fixed limit).
- **Cell size**: 8‑bit unsigned integers with modulo‑256 wrap‑around.
- **I/O**: Byte‑level reading from `stdin` and writing to `stdout` (ASCII).
- **Error handling**: Detects unmatched brackets and invalid instructions.
- **Code generator**: Generates a BF program that outputs a given string (uses a block‑based initialisation strategy to minimise code size).
- **Interactive REPL**: Evaluate BF code, generate programs, run shell commands from output, and more.
- **Multilingual**: Outputs messages in English or Chinese based on the `LANG` environment variable.

---

## Installation

Just download the script and make it executable (or source it):

```bash
curl -O- https://raw.githubusercontent.com/hornleaf/brainfuck-shell/main/bf.sh | install -m 755 /dev/stdin /usr/bin/bf
```

To use the `brainfuck` and `brainfuck-generate` functions in your own scripts, source the file:

```bash
source bf
```

---

## Usage

### 1. Interpreter

The `brainfuck` function (or script) accepts code in three ways:

```bash
# Read from stdin (interactive, type code, Ctrl‑D to finish)
brainfuck

# Pass a string containing BF code
brainfuck "++++++++++[>++++++++++>++++++++++++>++++++++++<<<-]>+.>.>---.<<++++++++.+++.----.>>++++."

# Execute a .bf file (or any text file)
brainfuck program.bf

# Multiple arguments are concatenated
brainfuck "++++++[>+++++++++++>" "+<<-]>.++++." ">++++."
```

### 2. Code Generator

```bash
# Generate BF code for a string
brainfuck-generate "Hello, World!"

# Or use the --build option
bf --build "Hello, World!"
```

If the second argument is a file, the generated code is saved as `<file>.bf`.

### 3. Command‑Line Options

| Option           | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `--help`, `-h`   | Show help message.                                                          |
| `--version`, `-v`| Print version information and dependencies.                                 |
| `--build`, `-b`  | Generate BF code from the following string (or from stdin if piped).        |
| `--interact`, `-i`| Start the interactive REPL.                                               |

---

## Interactive REPL

Launch the REPL with:

```bash
bf --interact
```

Once inside, you can enter BF code directly. Special commands (prefix characters) are:

| Command | Description                                                                 |
|---------|-----------------------------------------------------------------------------|
| `!`     | Execute the previous BF output as a shell command.                          |
| `#`     | Generate BF code for the following string and print it.                    |
| `:`     | Clear the screen.                                                          |
| `?`     | Show this help information.                                                |
| `;`     | Exit the REPL (optional numeric exit code).                                |

**Example REPL session:**

```
> ++++++++[>++++[<+++>-]<-]>>.   # prints 'H'
> ! echo "BF output was used as command"   # runs the command
> # Hello
  [generated BF code for "Hello"]
```

---

## Examples

### Hello World
```bash
brainfuck "++++++++[>+++++++++>++++++++++++>+++++>++++>++++++++++>+<<<<<<-]>.>+++++.+++++++..+++.>++++.>.>+++++++.<<<.+++.------.--------.>>+.>>++."
# Output: Hello, World!
```

### Generate “Hello, World!” program
```bash
bf --build "Hello, World!"
```
This will output a compact BF program that prints the string.

### Run a `.bf` file
```bash
bf examples/hello.bf
```

### Interactive mode with code generation
```bash
bf -i
> # Brainfuck
```

---

## Dependencies

The script relies on standard GNU tools:

- **Bash** ≥ 4.0 (for associative arrays, `read -N`, etc.)
- **GNU coreutils** – `od`, `printf`, `tr`, `grep`, `sort`, `bc`
- **bc** – used for median and square‑root calculations in the generator.

All are typically installed on most Linux distributions. On macOS, install `coreutils` and `bc` via Homebrew.

---

## Technical Notes

- **Bracket matching** is done in a single pass; unbalanced brackets cause an error.
- **Tape expansion**: when the pointer moves beyond allocated cells, 128 new cells are added on the required side.
- **`read -N1`** is used for `,` to capture a single byte; `LC_ALL=C` ensures byte‑wise reading.
- **`printf` with octal escapes** outputs raw bytes correctly (no Unicode or multibyte issues).
- The **code generator** uses a block‑based approach: it initialises a set of “work” cells to multiples of a base value `d`, then uses them to produce each target byte efficiently.

---

## License & Author

This script is provided under the **MIT License**.

- **Author**: DeepSeek (AI‑assisted development)
- **Version**: 1.0.14

---

## Contributing

Feel free to open issues or pull requests. Areas for improvement:

- Support for non‑ASCII input/output (UTF‑8, wide chars).
- Optimisation of the code generator (shorter BF output).
- Performance enhancements for large programs.

---

## Acknowledgements

Inspired by the original Brainfuck language by Urban Müller (1993) and countless BF implementations.

Happy brainfucking! 🧠💥
