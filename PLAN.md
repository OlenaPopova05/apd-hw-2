# Implementation Plan

## Approach

I will implement the required TaskProcessor behavior using Swift structured concurrency. It will validate maximumConcurrency in initializer and check job IDs for duplicates before starting any worker. Also an empty input will return an empty result array.
For implementation I will use withTaskGroup to schedule an initial set of at most maximumConcurrency jobs. As workers finish, the processor will add the next unstarted job if scheduling is still allowed. Each child task will return the original input index and a JobOutcome, so results can be stored by index and returned in the same order as the input jobs.
If a worker completes successfully, it returns `.succeeded`, if an error occurs, it returns `.failed`, and if it is cancelled, it returns `.cancelled`. No new jobs should start if the `process` task is cancelled. In this case the processor should cancel the running jobs and mark all jobs that have not started as `.cancelled`.

## Milestones

- [+] Validate configuration and all job IDs before starting work.
- [+] Schedule jobs within the concurrency limit and preserve input order.
- [+] Map success, ordinary errors, and cancellation outcomes.
- [+] Handle caller cancellation and never-started jobs.
- [+] Add at least six distinct student-authored tests and run `swift test`.

## Risks and checks

- Workers can finish in any order, but the results must follow the original job order. The provided starter test will check this behavior.
- The processor must not run more workers than the allowed limit. Add a test using `ConcurrencyProbe` and `Gate` to check the number of active workers and whether a new job starts when a slot becomes available.
- Duplicate IDs must be detected before any worker starts. Add tests to check the first repeated ID and confirm that no worker was called.
- Worker errors should not stop the other jobs. Add a test with successful jobs, an ordinary error, and a `CancellationError` to check that each job gets the correct result.
- Caller cancellation must stop new jobs from starting and mark jobs that were never started as `.cancelled`. This behavior is handled in the processor using cancellation checks and `group.cancelAll()`.
