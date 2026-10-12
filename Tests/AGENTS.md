# Tests

Swift Testing.

- Parameterize over tables of inputs (`@Test(arguments:)`).
- No live I/O. `URLProtocol` stubs or in-memory fakes.
- Parallel by default. Shared mutable process state is a bug.
