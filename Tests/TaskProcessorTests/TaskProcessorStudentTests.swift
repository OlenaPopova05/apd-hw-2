import XCTest
@testable import TaskProcessor

private actor WorkerCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

private actor ConcurrencyProbe {
    private var active = 0
    private var maximumObserved = 0

    func started() {
        active += 1
        maximumObserved = max(maximumObserved, active)
    }

    func finished() {
        active -= 1
    }

    func maximum() -> Int {
        maximumObserved
    }
}

@MainActor
final class TaskProcessorStudentTests: XCTestCase {
    
    func testNegativeMaximumConcurrencyIsRejected() {
        XCTAssertThrowsError(
            try TaskProcessor(maximumConcurrency: -3)
        ) { error in
            XCTAssertEqual(
                error as? TaskProcessorError,
                .nonPositiveMaximumConcurrency
            )
        }
    }

    func testFirstRepeatedIDIsReported() async throws {
        let processor = try TaskProcessor(maximumConcurrency: 2)

        let jobs = [
            Job(id: "A", input: 1),
            Job(id: "B", input: 2),
            Job(id: "B", input: 3),
            Job(id: "A", input: 4)
        ]

        do {
            _ = try await processor.process(jobs) { job in
                job.input
            }

            XCTFail("Expected duplicateID error")
        } catch let error as TaskProcessorError {
            XCTAssertEqual(error, .duplicateID("B"))
        }
    }

    func testDuplicateValidationPreventsWorkerExecution() async throws {
        let processor = try TaskProcessor(maximumConcurrency: 3)
        let counter = WorkerCounter()

        let jobs = [
            Job(id: "A", input: 10),
            Job(id: "B", input: 20),
            Job(id: "A", input: 30)
        ]

        do {
            _ = try await processor.process(jobs) { job in
                await counter.increment()
                return job.input
            }

            XCTFail("Expected duplicateID error")
        } catch let error as TaskProcessorError {
            XCTAssertEqual(error, .duplicateID("A"))
        }

        let calls = await counter.value()
        XCTAssertEqual(calls, 0)
    }

    func testMultipleSuccessfulJobsReturnCorrectValues() async throws {
        let processor = try TaskProcessor(maximumConcurrency: 2)

        let jobs = [
            Job(id: "A", input: 3),
            Job(id: "B", input: 5),
            Job(id: "C", input: 7)
        ]

        let results = try await processor.process(jobs) { job in
            job.input * job.input
        }

        XCTAssertEqual(results, [
            JobResult(id: "A", outcome: .succeeded(9)),
            JobResult(id: "B", outcome: .succeeded(25)),
            JobResult(id: "C", outcome: .succeeded(49))
        ])
    }

    func testMixedWorkerOutcomes() async throws {
        let processor = try TaskProcessor(maximumConcurrency: 2)

        let jobs = [
            Job(id: "success", input: 10),
            Job(id: "failure", input: 20),
            Job(id: "cancelled", input: 30),
            Job(id: "success2", input: 40)
        ]

        let results = try await processor.process(jobs) { job in
            switch job.id {
            case "failure":
                throw SampleWorkerError.expected
            case "cancelled":
                throw CancellationError()
            default:
                return job.input * 2
            }
        }

        XCTAssertEqual(results, [
            JobResult(id: "success", outcome: .succeeded(20)),
            JobResult(id: "failure", outcome: .failed),
            JobResult(id: "cancelled", outcome: .cancelled),
            JobResult(id: "success2", outcome: .succeeded(80))
        ])
    }
    
    
    func testConcurrencyNeverExceedsLimit() async throws {
        let processor = try TaskProcessor(maximumConcurrency: 2)
        let gate = Gate()
        let probe = ConcurrencyProbe()

        let jobs = [
            Job(id: "A", input: 1),
            Job(id: "B", input: 2),
            Job(id: "C", input: 3)
        ]

        let processing = Task {
            try await processor.process(jobs) { job in
                await probe.started()

                await gate.wait(for: job.id)

                await probe.finished()
                return job.input
            }
        }

        await gate.waitUntilWaiting(for: "A")
        await gate.waitUntilWaiting(for: "B")

        let initialMaximum = await probe.maximum()
        XCTAssertEqual(initialMaximum, 2)

        await gate.release("A")
        await gate.waitUntilWaiting(for: "C")

        await gate.release("B")
        await gate.release("C")

        let results = try await processing.value
        let observedMaximum = await probe.maximum()

        XCTAssertLessThanOrEqual(observedMaximum, 2)
        XCTAssertEqual(results.count, 3)
    }

}
