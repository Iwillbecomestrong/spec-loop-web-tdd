# Grill-Me integration

This plugin includes a built-in Grill-Me-compatible clarification phase because the source workspace currently does not provide a separate `grill-me` skill.

The phase is required before planning:

1. Start from the user's request, not from an assumed implementation.
2. Read the available project truth and identify missing information.
3. Clarify purpose, scope, non-goals, constraints, interfaces, failure behavior, and acceptance criteria.
4. Ask one material question at a time when user input is needed.
5. Classify the work as Small, Standard, or Epic.
6. Create or update the appropriate SPEC.
7. Check the SPEC for contradictions, placeholders, and ambiguous acceptance criteria.
8. Obtain confirmation for a new or materially changed SPEC.
9. Only then create `docs/work/plan-prompt.txt` and call ChatGPT Web for the technical plan.

If a real Grill-Me skill is later supplied, it may replace this compatibility phase. It must still produce the same handoff contract: confirmed requirements, scope classification, SPEC path, open questions, and acceptance criteria.

## Suggested clarification record

```markdown
# Clarification record

## User goal

## Confirmed behavior

## Non-goals

## Constraints

## Acceptance criteria

## Affected modules

## Open questions

## SPEC path
```
