# LeetCards

A flashcard app for drilling the **high-level idea** behind LeetCode problems
(Top Interview 150). Show a problem → type the core idea → an on-device LLM
(Apple Foundation Models) grades it 0–100 → override the score if you disagree.
Tab between real community solutions while reviewing.

## Layout

- `pipeline/` — Python data pipeline (Stage 1): scrapes descriptions + top-3
  community solutions, summarizes a `core_idea` per problem, builds the bundled
  `dataset.json`. See `pipeline/` scripts.
- `App/` — SwiftUI app (Stage 2), macOS + iOS. Models, services (dataset
  loading, grading), stores (`DeckStore`, `FlashcardModel`), and views.
- `Tests/` — swift-testing regression suites.

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

## Regenerating the dataset

```sh
cd pipeline
python -m venv ../.venv && ../.venv/bin/pip install -r requirements.txt
../.venv/bin/python fetch_problem_list.py
../.venv/bin/python fetch_problems.py
# author/update out/core_ideas.json, then:
../.venv/bin/python summarize.py
cp out/dataset.json ../App/Resources/dataset.json
```
