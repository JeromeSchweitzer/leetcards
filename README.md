# LeetCards

A flashcard app for drilling the **high-level idea** behind LeetCode problems
(Top Interview 150). Show a problem → type the core idea → an on-device LLM
(Apple Foundation Models) grades it 0–100 → override the score if you disagree.
Tab between real community solutions while reviewing.

## Layout

- `App/` — SwiftUI app, macOS + iOS. Models, services (dataset loading,
  grading), stores (`DeckStore`, `FlashcardModel`), views, and theme.
- `Tests/` — swift-testing regression suites.

## Dataset

The app ships a small, self-authored **`App/Resources/dataset.sample.json`** so it
builds and runs out of the box. The loader prefers a full `dataset.json` when one
is present in `App/Resources/` (gitignored), and otherwise falls back to the
sample. Building a full problem set is done by a separate, unpublished pipeline
that is not part of this repository.

## Build & run

Two build systems compile the same `App/` + `Tests/` sources:

```sh
# SwiftPM — macOS target + tests (terminal workflow)
swift build
swift test
swift run            # launches the macOS app

# Xcode — iOS + macOS, app bundle, Simulator
xcodegen generate    # regenerate LeetCards.xcodeproj from project.yml
open LeetCards.xcodeproj
```

Requires full Xcode (for the SwiftData / FoundationModels macro plugins),
macOS/iOS 26 SDK. On-device grading needs an Apple-Intelligence-capable device;
otherwise the app falls back to a manual/mock grader.

## Tests run on every commit

A pre-commit hook builds and runs the suite, blocking the commit on failure.
Enable it once per clone:

```sh
git config core.hooksPath .githooks
```

Bypass in a pinch with `git commit --no-verify`.
