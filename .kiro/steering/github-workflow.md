---
inclusion: always
---

# GitHub workflow

- After every completed change in this repository, commit it and push it to GitHub without waiting to be asked.
- Never commit directly to `main`. Push to a feature branch and open a pull request into `main` (or update the open PR for the current task).
- Before pushing, run `flutter analyze` and `flutter test`; report the results in the PR description.
- Do not commit design preview screenshots (PNG renders) to the repository. `output/` is git-ignored; render previews locally only when needed.
