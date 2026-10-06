# Build a Hoard

A junkyard hoard-building game for Roblox. Pick up junk around a shared junkyard, carry it back to your plot and watch your hoard pile grow, then spend what you collect at stations and the workbench to grow faster.

Status: in development and not published yet.

## What's in it

- A pickup, carry and deposit loop, with piles that stack up on each player's plot
- Collection bins, gems with announcements, and an index of what you've found
- Stations and a workbench for upgrades, plus a hoard expansion
- A tutorial with an arrow that points at the next step
- A compact junkyard world with four player plots

## How it's built

- About 8,700 lines of Luau in client, server and shared modules, synced into Roblox Studio with Rojo.
- The server owns all progress. The client renders and sends requests, and an action limiter throttles them.
- Saves are versioned. Updates migrate old saves instead of wiping progress, and a failed load stops the join rather than starting someone over.
- 12 test suites in `tests/` with 278 gameplay assertions, plus tools in `tools/` that audit the world's surfaces, seams and collisions.

## Running it

Install Rojo, run `rojo serve`, and connect the Rojo plugin in Roblox Studio. The map and art live in the place file, which isn't in this repo. The scripts in `tools/` run in Studio's Edit mode.

Built solo by Sean Aminov, with AI coding assistants helping along the way.
