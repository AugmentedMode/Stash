// Dependency-free assertions for the Command Line Tools test executable.
// Tests use synthetic data, so failure diagnostics never include user history.
var failures = 0

func fail(_ file: String, _ line: UInt, _ message: String = "Assertion failed") {
    failures += 1
    print("FAIL: \(file):\(line): \(message)")
}

func XCTAssertEqual<T: Equatable>(
    _ lhs: @autoclosure () throws -> T, _ rhs: @autoclosure () throws -> T,
    file: String = #fileID, line: UInt = #line
) {
    do {
        let actual = try lhs()
        let expected = try rhs()
        if actual != expected {
            fail(
                file, line,
                "Expected \(String(describing: expected).prefix(160)); got \(String(describing: actual).prefix(160))"
            )
        }
    } catch {
        fail(file, line, "Unexpected error: \(error)")
    }
}

func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, file: String = #fileID, line: UInt = #line) {
    do {
        if try !value() { fail(file, line, "Expected true") }
    } catch {
        fail(file, line, "Unexpected error: \(error)")
    }
}

func XCTAssertNil<T>(
    _ value: @autoclosure () -> T?, _ message: String = "Expected nil",
    file: String = #fileID, line: UInt = #line
) {
    if value() != nil { fail(file, line, message) }
}

func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, file: String = #fileID, line: UInt = #line) {
    if value() == nil { fail(file, line, "Expected a value") }
}

func XCTAssertGreaterThan<T: Comparable>(_ lhs: T, _ rhs: T, file: String = #fileID, line: UInt = #line) {
    if lhs <= rhs { fail(file, line, "Expected \(lhs) > \(rhs)") }
}

func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () throws -> T, file: String = #fileID, line: UInt = #line
) {
    do {
        _ = try expression()
        fail(file, line, "Expected an error")
    } catch {
        // Any thrown error satisfies this assertion.
    }
}
