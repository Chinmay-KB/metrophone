# GitHub Actions

## Version gate

`PR version gate / Version monotonicity` runs for pull requests targeting `main`
or `master`. It reads `pubspec.yaml` from the PR and from the exact target-branch
revision and requires both values to increase:

- `MAJOR.MINOR.PATCH` must be greater;
- Android `BUILD` (the value after `+`) must be greater.

For example, if the target branch contains `1.0.0+1`, a PR could use `1.0.1+2`.
`1.0.1+1` and `1.0.0+2` both fail because only one component advanced.

To make the failure block merging, configure a GitHub branch protection rule or
ruleset for the repository's default branch and require this check by its exact
job name:

```text
Version monotonicity
```

Also block direct pushes or require pull requests so changes cannot bypass the
gate, and require branches to be up to date before merging. If GitHub's merge
queue is enabled, the workflow already handles its `merge_group` event.
Enable required CODEOWNER review as well to protect changes to the workflow and
version comparator.

The PR check uses `pull_request_target` only to load its trusted comparator from
the target revision. The proposed revision is checked out without credentials to
a separate directory, and only its `pubspec.yaml` is read; PR-controlled scripts
are never executed by the privileged event.

## Android artifacts

Every push to `main` or `master`, including a merged PR, runs analysis and tests,
then builds both:

- `build/app/outputs/flutter-apk/app-release.apk`;
- `build/app/outputs/bundle/release/app-release.aab`.

They are uploaded together as a GitHub Actions artifact named with the app
version and commit SHA and retained for 30 days. The workflow can also be run
manually.

The release build commands intentionally allow Flutter's internal package
configuration pass instead of using `--no-pub`. This avoids the current Flutter
tool regression that can incorrectly register the test-only `integration_test`
plugin in a release build when dependency resolution is separated from the
build command.

The current Android Gradle configuration signs release outputs with the debug
key. These artifacts are suitable for CI testing and direct APK installation,
but the AAB is not suitable for Play Store production. Configure a protected
release keystore before publishing to Google Play.
