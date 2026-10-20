# Agent Worklog

I used ChatGPT to help me understand the assignment, write the `TaskProcessor` implementation, and create additional XCTest tests. I asked questions about Swift concurrency and reviewed the suggested code to understand how it works. Also I wrote some parts of the code by myself to get to know the syntax.

| Date | Tool / model | Task or recommendation | My review and decision | Evidence |
| --- | --- | --- | --- | --- |
| 2026-10-19 | ChatGPT | Asked for help understanding the assignment requirements and planning the implementation steps. | I reviewed the requirements and organized the main tasks into a step-by-step implementation plan. | `PLAN.md` |
| 2026-10-20 | ChatGPT | Discussed different approaches to processing jobs concurrently and asked for help with the `TaskGroup` implementation. | I considered how to manage the jobs and keep their results in the correct order. After reviewing the suggested implementation, I asked additional questions to better understand the logic and decided to use this approach. | `Sources/TaskProcessor/TaskProcessor.swift` |
| 2026-10-20 | ChatGPT | Discussed error handling and cancellation in the `TaskProcessor`. | I reviewed how different errors should be handled and how cancellation affects the remaining jobs. I kept the suggested approach because it follows the assignment requirements. | `Sources/TaskProcessor/TaskProcessor.swift` |
| 2026-10-20 | ChatGPT | Asked for help understanding the provided tests and writing my own XCTest tests. | I reviewed the tests and used helpers such as `WorkerCounter`, `ConcurrencyProbe`, and `Gate` to test the processor's behavior. | `Tests/TaskProcessorTests/TaskProcessorStudentTests.swift` |

## Final review

I reviewed the implementation and tests to make sure they follow the assignment requirements. All tests passed successfully. I added an artifact with tests results.
