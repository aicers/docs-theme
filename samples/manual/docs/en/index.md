# Sample Manual

This page exercises every visual element supported by the manual
template. Use it to verify that styles render correctly in both
the browser and PDF output.

## Inline Formatting

Regular text with **bold**, *italic*, ***bold italic***, `inline code`,
~~strikethrough~~, and [a hyperlink](https://example.com). You can also
use the ++ctrl+shift+p++ keyboard shortcut.

The HTML specification is maintained by the W3C.

*[HTML]: Hyper Text Markup Language
*[W3C]: World Wide Web Consortium

---

## Lists

### Unordered (3 levels)

- Fruit
    - Citrus
        - Orange
        - Lemon
    - Berry
        - Blueberry
        - Strawberry
- Vegetables
    - Root
        - Carrot
        - Potato

### Ordered (3 levels)

1. Prepare the environment
    1. Install dependencies
        1. System packages
        2. Language runtime
    2. Configure credentials
2. Run the application
    1. Start the database
    2. Start the server
3. Verify the deployment

### Task List

- [x] Set up repository
- [x] Configure CI pipeline
- [ ] Write documentation
- [ ] Tag first release

### Definition List

MkDocs
:   A static site generator geared towards building project
    documentation, written in Python.

Material for MkDocs
:   A theme for MkDocs that provides a modern, responsive design
    with many built-in features.

---

## Tables

### Simple Table

| Component   | Version | Status      |
|-------------|---------|-------------|
| Server      | 2.4.0   | Stable      |
| CLI         | 1.8.3   | Stable      |
| Dashboard   | 0.9.1   | Beta        |

### Aligned Columns

| Left-aligned | Center-aligned | Right-aligned |
|:-------------|:--------------:|--------------:|
| Row 1        |    Alpha       |         1,024 |
| Row 2        |    Beta        |         2,048 |
| Row 3        |    Gamma       |         4,096 |

---

## Code Blocks

### With Line Numbers

```python linenums="1"
def fibonacci(n: int) -> list[int]:
    """Return the first n Fibonacci numbers."""
    seq = []
    a, b = 0, 1
    for _ in range(n):
        seq.append(a)
        a, b = b, a + b
    return seq
```

### Without Line Numbers

```bash
curl -sSL https://example.com/install.sh | bash
```

### Multiple Languages

=== "Python"

    ```python
    print("Hello, world!")
    ```

=== "Rust"

    ```rust
    fn main() {
        println!("Hello, world!");
    }
    ```

=== "Go"

    ```go
    package main

    import "fmt"

    func main() {
        fmt.Println("Hello, world!")
    }
    ```

---

## Admonitions

!!! note
    This is a **note** admonition. Use it for supplementary information
    that the reader should be aware of.

!!! tip
    This is a **tip** admonition. Use it for best practices or
    helpful shortcuts.

!!! warning
    This is a **warning** admonition. Use it when the reader should
    proceed with caution.

!!! danger
    This is a **danger** admonition. Use it for actions that could
    cause data loss or security issues.

!!! info
    This is an **info** admonition. Use it for general contextual
    information.

!!! example
    This is an **example** admonition. Use it to illustrate a concept
    with a concrete scenario.

??? note "Collapsible admonition (click to expand)"
    This content is hidden by default and revealed when the reader
    clicks the title.

---

## Block Quotes

> Documentation is a love letter that you write to your future self.
>
> — Damian Conway

---

## Images and Figures

![Placeholder diagram](assets/placeholder.svg)

*Figure 1 — Sample architecture diagram*

---

## Footnotes

Bootroot manages service lifecycles on bare-metal hosts[^1]. It
coordinates with the package registry to fetch signed artifacts[^2].

[^1]: Bare-metal deployment avoids the overhead of container
      orchestration for latency-sensitive workloads.
[^2]: Artifact signatures are verified using ed25519 keys stored
      in the trust database.

---

## Heading Levels

### Third-level Heading

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua.

#### Fourth-level Heading

Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris
nisi ut aliquip ex ea commodo consequat.
