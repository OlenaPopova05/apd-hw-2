// Sendable -- object of this type can be passed between different concurrency contexts (e.g. between tasks or actors)
// Equatable -- allows to compare two objects via ==
public struct Job: Sendable, Equatable {
    public let id: String
    public let input: Int

    public init(id: String, input: Int) {
        self.id = id
        self.input = input
    }
}

public enum JobOutcome: Sendable, Equatable {
    case succeeded(Int)
    case failed
    case cancelled
}

public struct JobResult: Sendable, Equatable {
    public let id: String
    public let outcome: JobOutcome

    public init(id: String, outcome: JobOutcome) {
        self.id = id
        self.outcome = outcome
    }
}

public enum TaskProcessorError: Error, Equatable {
    case nonPositiveMaximumConcurrency
    case duplicateID(String)
}

public actor TaskProcessor {
    private let maximumConcurrency: Int
    
    public init(maximumConcurrency: Int) throws {
        guard maximumConcurrency > 0 else {
            throw TaskProcessorError.nonPositiveMaximumConcurrency
        }
        self.maximumConcurrency = maximumConcurrency
    }
    // @escaping -- allows a closure to be stored and executed after the function returns
    public func process(
        _ jobs: [Job],
        worker: @escaping @Sendable (Job) async throws -> Int
    ) async throws -> [JobResult] {
        
        var usedIds = Set<String>()
        for job in jobs {
            guard !usedIds.contains(job.id) else {
                throw TaskProcessorError.duplicateID(job.id)
            }
            usedIds.insert(job.id)
        }
        
        guard !jobs.isEmpty else {
            return []
        }
        
        return await withTaskGroup(
                of: (Int, JobOutcome).self,
                returning: [JobResult].self
            ) { group in

                var outcomes = Array<JobOutcome?>(repeating: nil, count: jobs.count)

                var nextIndex = 0
                var cancellationObserved = false

                func submit(
                    _ index: Int,
                    into group: inout TaskGroup<(Int, JobOutcome)>
                ) -> Bool {
                    let job = jobs[index]

                    return group.addTaskUnlessCancelled {
                        do {
                            let value = try await worker(job)
                            return (index, .succeeded(value))
                        } catch is CancellationError {
                            return (index, .cancelled)
                        } catch {
                            return (index, .failed)
                        }
                    }
                }

                let initialCount = min(maximumConcurrency,jobs.count)

                for _ in 0..<initialCount {
                    if Task.isCancelled || group.isCancelled {
                        cancellationObserved = true
                        group.cancelAll()
                        break
                    }

                    guard submit(nextIndex, into: &group) else {
                        cancellationObserved = true
                        group.cancelAll()
                        break
                    }

                    nextIndex += 1
                }

                while let (index, outcome) = await group.next() {
                    outcomes[index] = outcome

                    if Task.isCancelled || group.isCancelled {
                        cancellationObserved = true
                        group.cancelAll()
                    }

                    if !cancellationObserved && nextIndex < jobs.count {
                        if submit(nextIndex, into: &group) {
                            nextIndex += 1
                        } else {
                            cancellationObserved = true
                            group.cancelAll()
                        }
                    }
                }

                for index in nextIndex..<jobs.count {
                    outcomes[index] = .cancelled
                }

                return jobs.enumerated().map { index, job in
                    JobResult(
                        id: job.id,
                        outcome: outcomes[index] ?? .cancelled
                    )
                }
            }
        }
    }


public struct RetryPolicy: Sendable, Equatable {
    public let maximumAttempts: Int
    
    public init(maximumAttempts: Int) throws {
        guard maximumAttempts > 0 else {
            throw RetryPolicyError.nonPositiveMaximumAttempts
        }
        
        self.maximumAttempts = maximumAttempts
    }
}

public enum RetryPolicyError: Error, Equatable {
    case nonPositiveMaximumAttempts
}

public extension TaskProcessor {
    func process(
        _ jobs: [Job],
        retryPolicy: RetryPolicy,
        worker: @escaping @Sendable (Job, Int) async throws -> Int
    ) async throws -> [JobResult] {

        try await process(jobs) { job in

            for attempt in 1...retryPolicy.maximumAttempts {
                try Task.checkCancellation()

                do {
                    return try await worker(job, attempt)

                } catch is CancellationError {
                    throw CancellationError()

                } catch {
                    try Task.checkCancellation()

                    if attempt == retryPolicy.maximumAttempts {
                        throw error
                    }
                }
            }

            throw CancellationError()
        }
    }
}
