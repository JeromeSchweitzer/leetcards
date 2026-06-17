# CLAUDE.md

Guidance for working in this repo.

## Always run the tests after substantial changes

After any large or multi-file change, run the regression suite **even if you are
not committing yet**:

```sh
swift build && swift test
```

Don't wait for commit time to discover breakage. The same suite runs
automatically as a **pre-commit hook** (`.githooks/pre-commit`, enabled via
`git config core.hooksPath .githooks`), but run it proactively while iterating so
problems surface early.

Every behavioral change should come with a regression test (the suite is
dependency-free swift-testing under `Tests/`). UI/layout specifics that can't be
asserted in `swift test` are backed by a testable seam (a pure function, a
`Layout` constant, or a model rule) plus visual verification of the running app.

## Build / test / run

```sh
swift build            # macOS target (SwiftPM)
swift test             # all regression suites
swift run              # launch the macOS app

xcodegen generate      # regenerate LeetCards.xcodeproj (iOS + macOS, app bundle)
```

Full Xcode is required (SwiftData / FoundationModels macro plugins, macOS/iOS 26
SDK). SwiftPM builds the **macOS** target only; use Xcode for iOS/Simulator.

## Layout

- `pipeline/` — Python data pipeline that builds the bundled `dataset.json`.
- `App/` — SwiftUI app (macOS + iOS): `Models/`, `Services/` (dataset + grading),
  `Stores/` (`DeckStore`, `FlashcardModel`), `Views/`, `Theme/`.
- `Tests/` — swift-testing regression suites.

## Conventions

- Keep grading/UI logic in testable types (e.g. `FlashcardModel`, pure functions
  like `parseMarkdownBlocks`, `scoreColor`) rather than inside views.
- The dataset is loaded forward-compatibly (unknown JSON fields ignored, optional
  fields defaulted); the on-device grader (`FoundationModelsGrader`) falls back to
  `MockGrader` when Apple Intelligence is unavailable. **Tests must never call the
  real model** — use `MockGrader`.
