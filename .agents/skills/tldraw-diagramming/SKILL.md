---
name: tldraw-diagramming
description: Use this skill whenever diagrams are requested by the user. Create, inspect, and iteratively refine diagrams in tldraw via the local Canvas API at localhost:7236.
---

# tldraw diagramming

Use this skill whenever the user asks for a diagram, flowchart, architecture picture, sequence view, or canvas edit.

## Purpose

This workflow uses the local tldraw Desktop Canvas API at `http://localhost:7236` to create and refine diagrams programmatically.

Prefer small, incremental edits. For a non-trivial diagram:

1. Understand the subject from source material first.
2. Create a first-pass diagram with a small number of shapes.
3. Inspect the document state.
4. Tighten labels, layout, and hierarchy in follow-up edits.

## Default workflow

Use these endpoints in order:

```text
GET  /api/doc
GET  /api/doc/:id/shapes
POST /api/doc/:id/actions
GET  /api/doc/:id/screenshot
```

Recommended sequence:

1. `curl http://localhost:7236/api/doc`
2. If no doc exists, open tldraw and create one.
3. Choose the active doc ID.
4. `curl http://localhost:7236/api/doc/<DOC_ID>/shapes`
5. Post grouped actions to create or update the diagram.
6. Re-read shapes to verify the result.
7. Optionally capture a screenshot for visual verification.

## Document setup

- If `GET /api/doc` returns no docs, open the `tldraw` app and create a new document.
- A practical way to do this locally is:

```bash
open -a "tldraw"
osascript -e 'tell application "tldraw" to activate' -e 'tell application "System Events" to keystroke "n" using command down'
```

- Then re-run `GET /api/doc` until a document appears.

## Diagramming heuristics

- Start with the core flow, then add side effects and notes.
- Use short labels. Prefer noun or verb phrases over sentences.
- Keep one main reading direction: left-to-right or top-to-bottom.
- Use notes sparingly for exceptions, retries, or caveats.
- Group related edits into a single `actions` call so undo works cleanly.
- Prefer `place`, `align`, `distribute`, and `stack` over micro-positioning when possible.
- Verify the diagram after each meaningful edit with `/shapes` and optionally `/screenshot`.

## Good shape choices

- `rectangle` for systems, services, processors, jobs, and databases
- `text` for titles and section headers
- `note` for caveats, retries, dedupe behavior, and optional branches
- `arrow` with `fromId` and `toId` for connections

Default style guidance:

- Use mostly default black outlines and minimal fill.
- Reserve colored fills for emphasis only.
- Keep the palette restrained and consistent.
- Avoid overly dense text inside shapes.

## Editing patterns

For first-pass creation, send one POST with all primary shapes and arrows.

For refinement, prefer:

- `label` to shorten wording
- `move` to change reading order
- `align` and `distribute` to clean layout
- `resize` only when text needs more or less room
- `bringToFront` for titles and notes when needed

## Vertical vs horizontal flow

- Use vertical flow when the process is linear and stage-based.
- Use horizontal flow when comparing systems or keeping labels short.
- Keep side branches off to one side rather than breaking the main spine.

## When the user asks to tighten or polish

Default refinements:

- Shorten labels first
- Reduce the number of notes
- Make the main flow visually dominant
- Convert to vertical flow if that improves readability
- Rename arrows only when the branch meaning is not obvious

## Verification checklist

Before finishing, confirm:

- A document exists and the intended doc ID was edited
- The main flow matches the requested subject
- Labels are concise
- Shapes read in a clear order
- Important side effects or edge cases are present, but not over-explained

## Example actions payload

```json
{
	"actions": [
		{
			"_type": "create",
			"shape": {
				"_type": "text",
				"shapeId": "title",
				"x": 800,
				"y": 20,
				"anchor": "top-center",
				"color": "black",
				"fontSize": 32,
				"maxWidth": 900,
				"note": "",
				"text": "System flow"
			}
		},
		{
			"_type": "create",
			"shape": {
				"_type": "rectangle",
				"shapeId": "step1",
				"x": 650,
				"y": 120,
				"w": 280,
				"h": 140,
				"color": "black",
				"fill": "none",
				"note": "",
				"text": "Producer"
			}
		},
		{
			"_type": "create",
			"shape": {
				"_type": "rectangle",
				"shapeId": "step2",
				"x": 650,
				"y": 340,
				"w": 280,
				"h": 140,
				"color": "black",
				"fill": "none",
				"note": "",
				"text": "Consumer"
			}
		},
		{
			"_type": "create",
			"shape": {
				"_type": "arrow",
				"shapeId": "a1",
				"fromId": "step1",
				"toId": "step2",
				"color": "black",
				"note": ""
			}
		}
	]
}
```

## Communication pattern

When reporting back to the user:

- State what the diagram now shows
- Mention whether you optimized for clarity, brevity, vertical flow, or presentation quality
- Offer a small next-step set such as tightening labels, adding detail, or exporting a screenshot
