---
name: dothework
description: End-to-end card workflow. Takes a Launchbox card short code (e.g. lau-879), checks out a fresh branch from main, moves the card to Development, drives the work TDD-style, opens a PR, and finally moves the card to Automated Review. Invoke when the user runs `/dothework <short-code>`.
---

# Do The Work

This skill takes a Launchbox card from "ready to start" to "in automated review" with no shortcuts. You are responsible for delivering tested, reviewed-ready code on a branch with an open PR.

The skill takes one argument: a Launchbox card short code (e.g. `lau-879`). If the user invokes `/dothework` without an argument, ask which card they want to work.

## Workflow — execute these steps in order

### 1. Sync local main and stash any in-progress work

```
git checkout main && git pull
```

If `git status` shows uncommitted changes after the checkout, run `git stash push -u -m "dothework auto-stash"` to keep the workspace clean. Tell the user you stashed their changes so they can restore them later with `git stash pop`. Do not delete or discard work without permission.

### 2. Look up the card and check out its branch

Use `mcp__launchbox-prod__search_cards` with the short code to find the card. Capture:
- card id
- title
- notes (the card description)
- `suggested_branch_name`
- the board_placement (board id + current column id)

Then create the branch from the just-pulled main:

```
git checkout -b <suggested_branch_name>
```

If the branch already exists locally, check it out and `git pull --ff-only` if there's a remote. If the branch already has unrelated commits, stop and ask the user how to proceed.

### 3. Move the card to Development and assign yourself

Find the Development column on the card's current board (use `mcp__launchbox-prod__get_kanban_board` if you don't already know the column id), then call `mcp__launchbox-prod__move_card_to_column` to move the card there. Skip if it's already in Development.

Then assign the developer running the skill to the card so the board reflects who's working on it:

1. Read the developer's email from git: `git config user.email`.
2. Call `mcp__launchbox-prod__get_users` to list active members of the current organization and find the one whose `email` matches.
3. Call `mcp__launchbox-prod__assign_user` with `card_id` and the matched `user_id`.

`assign_user` is additive — a card can have multiple assignees, so it's safe to run even if someone else has already picked up the card. If the same user is already assigned, the tool returns the error `"User is already assigned to this card"` — treat that string as success and continue, don't fail the workflow.

If no organization member matches the git email (e.g. the developer hasn't been added to the org, or the git email is misconfigured), warn the user and skip the assignment — don't fail the workflow either.

### 4. Read the card description and project documentation

- Re-read the card notes you captured in step 2
- Read `CLAUDE.md` at the project root
- Read any other project documentation that looks relevant (e.g. `README.md`, files referenced in CLAUDE.md, the relevant context module's moduledoc)

The goal is to load enough context that you can make good design decisions without guessing.

### 5. Web research for technical unknowns

If the card touches a library, API, or pattern you're not certain about, use WebSearch / WebFetch to look it up. Prefer official docs. Write down (in your own working notes, not the codebase) the conclusions you reach so you don't have to re-research later.

### 6. Interview the user for design and product gaps

After research, ask the user any questions you still have about scope, behavior, or design. Use `AskUserQuestion` for choices between concrete options. Skip this step only if the card and docs already give you everything you need.

### 7. Work the card with a TDD red-green-refactor loop

Follow the project's `tdd` skill rigorously:

1. Write a failing test that captures one slice of behavior
2. Run the test, confirm it fails for the right reason
3. Implement the minimum code to make it pass
4. Run the test, confirm it passes
5. Refactor if needed, keeping tests green
6. **Run `mix test`** before moving to the next red test — this catches formatting, credo, sobelow, and coverage problems while the change is still small
7. Repeat until the slice is done

If `mix test` fails, fix it before proceeding. Never accumulate broken state.

**Before moving to the next slice, verify consistency with sibling code:**

- **Scope and policy:** Every new context function that mutates data must accept `%Scope{}` and call a 2-arity policy function that checks both role and org ownership. If you wrote a context function without scope, fix it before proceeding.
- **Match adjacent patterns:** Before writing a new tool handler, LiveView event handler, or channel handler, read 2-3 existing ones in the same module. Match their structure — error formatting, `with` vs `case`, scope passing, broadcast patterns. Most review feedback comes from inconsistency with sibling code.
- **PubSub events in LiveViews:** When adding a new event to a LiveView's event list, verify the LiveView actually renders the affected data. If it doesn't, handle the event as a no-op.

### 8. Self-review before committing

Before staging anything, **re-read the relevant sections of `AGENTS.md`** (especially return-value discipline, Oban workers, context boundaries, and authorization) and check your memory files for prior feedback. Then scan the diff for these patterns that consistently cause review feedback:

- [ ] **No discarded return values.** Every context/Repo call that returns `{:ok, _} | {:error, _}` is handled with `case` or `with` — no bare `=` matches on failable calls. **This includes `Oban.insert/1`** — a discarded insert silently strands the pipeline if enqueueing fails.
- [ ] **No LiveView → Repo.** No LiveView aliases or calls `Repo` directly. Cross-context transactions live in a context function.
- [ ] **Thin Oban workers.** No Oban worker contains business logic beyond orchestration (~30 lines max). LLM calls, batch writes, and error classification live in a context module (e.g. `KnowledgeBase.Embedder`).
- [ ] **Correct Oban return values.** `:ok` only for permanent success. `{:error, reason}` for retryable failures. `{:snooze, n}` for polling. No silent swallowing of errors.
- [ ] **No N+1 loops.** No `Enum.each`/`Enum.map` calling a Repo function inside the body — use `Repo.insert_all`/`Repo.update_all` for batch operations.
- [ ] **Pipeline status ownership.** In multi-job chains, only the final job sets the terminal status. No premature "ready" before enqueueing the next job.
- [ ] **LLM response guards.** All `{:ok, %{content: content}}` matches include `when is_binary(content)`.
- [ ] **Context boundaries.** No job or LiveView reaches into another context's schema for writes.
- [ ] **Comments earn their length.** Every comment in the diff is shorter than the code it explains and says something the code cannot. Delete restated-code comments rather than rewording them. Grep the diff for the stock phrases listed under Writing Style in `CLAUDE.md` and cut them — from comments, commit messages, and the PR body alike.
- [ ] **Environment configs in sync.** If the diff touches `.devcontainer/` (Dockerfile, compose.yaml, post-start.sh, devcontainer.json), it makes the matching change in `.launchbox/vm.json` / `.launchbox/supervisord.conf` — and vice versa. A package belongs in both, a service needs a `[program:...]` plus whatever installs it, an env var needs the `/etc/profile.d` step. See the Development Environment section of `CLAUDE.md`.

Fix any violations before committing.

### 9. Commit in semantic chunks

Group changes into commits that each tell a coherent story. Prefer multiple small commits over one giant one. Use semantic prefixes that match the repo's existing convention (look at `git log --oneline -20`).

Always include the card short code in commit messages so the GitHub webhook can link the PR back to the card automatically.

**Do not add `Co-Authored-By` or other attribution lines to commit messages.** CLAUDE.md forbids them, and Claude Code's default commit behavior adds them — you must explicitly omit attribution footers when crafting the commit message.

### 10. Push and open a PR after the first commit

After the **first** commit lands locally:

```
git push -u origin <branch>
```

Then open a PR with `gh pr create`. Title should include the card short code. Body should have a Summary and Test plan section.

Subsequent commits just need `git push` — the PR updates automatically.

## Hard rules

- **Never skip test between green tests.** That's the whole point of running it small and often.
- **Never force-push or use `--no-verify`** unless the user explicitly tells you to.
- **Never move the card to Done.** Automated Review is the terminal step for this skill.
- **If anything fails along the way**, stop and tell the user — don't paper over failures to keep moving.
