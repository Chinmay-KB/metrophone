import unittest

from tool.verify_version import AppVersion, parse_pubspec, verify_versions


class VersionCheckTests(unittest.TestCase):
    def test_parses_flutter_version(self) -> None:
        self.assertEqual(
            parse_pubspec("name: metrophone\nversion: 2.3.4+57\n", "fixture"),
            AppVersion(2, 3, 4, 57),
        )

    def test_requires_semantic_version_bump(self) -> None:
        with self.assertRaisesRegex(ValueError, "semantic version"):
            verify_versions(AppVersion(1, 0, 0, 2), AppVersion(1, 0, 0, 1))

    def test_requires_android_build_number_bump(self) -> None:
        with self.assertRaisesRegex(ValueError, "Android build number"):
            verify_versions(AppVersion(1, 0, 1, 1), AppVersion(1, 0, 0, 1))

    def test_accepts_both_increasing(self) -> None:
        verify_versions(AppVersion(1, 1, 0, 2), AppVersion(1, 0, 9, 1))

    def test_rejects_non_numeric_version(self) -> None:
        with self.assertRaisesRegex(ValueError, "MAJOR.MINOR.PATCH\\+BUILD"):
            parse_pubspec("version: 1.0.0-beta+2\n", "fixture")


if __name__ == "__main__":
    unittest.main()
