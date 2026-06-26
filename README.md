> [!Note] Although this project was 100% vibe-coded, everything is this README was written manually by Jerome Schweitzer :)

# LeetCards

Proof-of-concept for using Claude Code to develop a Swift project for reviewing the high-level ideas behind competive programming problems.

## Development Process w/ AI Tools

### Tool Specs

| Agentic System | Model    | IDE                            |
|----------------|----------|--------------------------------|
| Claude Code    | Opus 4.8 | VSCode (w/ Claude Code extension) |

### Project Plan
Below are project details I gave AI on deliverables, expectations, testing, and verification.

#### Executive Description
A flashcards app to enforce core ideas to competitive programming problems scraped from a third party. Modern design, problem-set selection using filters and tags, dataset customizability, solution review.
#### Requirements
* The app should run on both Mac and iPhone.
* There should be a local database of competitive programming questions.
* Updating the dataset with new problems should be trivial.
* The user should be able to manually and richly select a problem set for each session of flashcards.
* Local AI should evaluate user answers to establish a baseline score.
* The user should be able to manually override the AI answer score.
* The app should have more than one color themes.
* Answer cards should cite and present multiple community solutions to programming problems.
* The UI should render markdown syntax that exists in the dataset.
* A "Summary" page should siaply when the user compeltes a problem set.
* Problem selection page should display tags.
* Problem selection page should display previous attempt information.
* Problem selection page should display relevant meta-data for each problem.

### Verification Plan

> [!Warning] Rough draft as of June 26 2026
* Mainly manual (me) testing and verification (avoiding Claude screensharing permissions for now)
* Bake regression tests into a precommit task
* After each milestone or significant changes, run regression tests

## Results

