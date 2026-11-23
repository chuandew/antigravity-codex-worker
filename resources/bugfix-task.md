# Bugfix Task Specification: {{TASK_ID}}

## 1. Symptom & Reproduction
- **Observed Bug**: <!-- Describe failing behavior, error message, or stack trace -->
- **Expected Behavior**: <!-- Describe exact expected behavior -->
- **Reproduction Command / Scenario**:
  ```text
  {{REPRO_COMMAND}}
  ```

## 2. Root-Cause Hypothesis & Scope
- **Suspected Location(s)**:
  - `path/to/file` (around function/lines ...)
- **Strict Constraints**:
  - Keep the fix minimal, targeted, and surgical — do NOT bundle unrelated refactoring or formatting sweeps.
  - Add or update a regression test covering this exact bug.
  - Do NOT run `git commit`, `git push`, or destructive git commands. Leave changes in the working tree for review.
  - **No Over-Defensive Coding**:
    - Validate inputs ONLY at system boundaries (API/CLI/external I/O); trust internal function contracts and static types — do NOT add redundant null/type checks inside internal helpers.
    - Prefer fail-fast over silent fallbacks or speculative `try/catch` blocks.
    - Do NOT introduce single-use abstractions, compatibility shims, or "just-in-case" branches not requested in the fix plan.
    - Avoid obvious line-by-line narration comments; only comment non-obvious invariants or "why".

## 3. Fix Plan
1. Confirm the root cause in code (if the actual root cause differs from the hypothesis above, fix the real root cause and explain clearly in your summary).
2. Apply the minimal fix: ...
3. Add/update regression test in: ...

## 4. Verification
Run and ensure all pass:
```text
{{VERIFY_COMMANDS}}
```

## 5. Required Final Summary Format
1. **Confirmed Root Cause**: File, line, and mechanism of the defect.
2. **Fix & Regression Test**: Summary of code changes and test added.
3. **Verification Results**: Output summary of test runs.
