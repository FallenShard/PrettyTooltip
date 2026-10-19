"""Checks that CI rejects broken packages and cannot silently bless baselines."""

import contextlib
import io
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from zipfile import ZIP_STORED, ZipFile

import check_package
import run as regression


class PackageChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = check_package.ROOT
        toc = (root / check_package.TOC).read_text(encoding="utf-8")
        toc = re.sub(r"#@debug@.*?#@end-debug@", "", toc, flags=re.DOTALL)
        cls.files = {check_package.TOC: toc.encode("utf-8"), "LICENSE": (root / "LICENSE").read_bytes()}
        for line in toc.splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                name = line.split(" [", 1)[0].replace("\\", "/")
                cls.files[name] = (root / name).read_bytes()
        for path in (root / "art").glob("*.tga"):
            cls.files[path.relative_to(root).as_posix()] = path.read_bytes()

    def check_archive(self, files):
        buffer = io.BytesIO()
        with ZipFile(buffer, "w", ZIP_STORED) as archive:
            for name, content in files.items():
                archive.writestr(f"PrettyTooltip/{name}", content)
        with ZipFile(buffer) as archive:
            return check_package.check_contents(archive)

    def test_release_contents_and_startup(self):
        entries, sources = self.check_archive(self.files)
        with contextlib.redirect_stdout(io.StringIO()):
            check_package.check_startup(entries, sources)

    def test_missing_locale(self):
        files = dict(self.files)
        del files["Locale/koKR.lua"]
        with self.assertRaisesRegex(ValueError, "missing packaged files.*koKR"):
            self.check_archive(files)

    def test_wrong_filename_case(self):
        files = dict(self.files)
        files["Locale/kokr.lua"] = files.pop("Locale/koKR.lua")
        with self.assertRaisesRegex(ValueError, "missing packaged files.*koKR"):
            self.check_archive(files)

    def test_missing_texture(self):
        files = dict(self.files)
        del files["art/logo.tga"]
        with self.assertRaisesRegex(ValueError, "missing packaged files.*logo"):
            self.check_archive(files)

    def test_changed_locale_condition(self):
        files = dict(self.files)
        files[check_package.TOC] = files[check_package.TOC].replace(b"AllowLoadTextLocale koKR", b"AllowLoadTextLocale enUS")
        with self.assertRaisesRegex(ValueError, "locale conditions differ"):
            self.check_archive(files)

    def test_debug_capture_leak(self):
        files = dict(self.files)
        files["UI/Capture.lua"] = b"-- debug code"
        with self.assertRaisesRegex(ValueError, "development file leaked"):
            self.check_archive(files)

    def test_broken_packaged_lua(self):
        entries, sources = self.check_archive(self.files)
        sources["PrettyTooltip.lua"] = "local = broken"
        with self.assertRaisesRegex(ValueError, "Lua syntax error"):
            check_package.check_startup(entries, sources)

    def test_broken_packaged_startup(self):
        entries, sources = self.check_archive(self.files)
        sources["Locale/koKR.lua"] = "error('broken locale startup')"
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, "startup failed for koKR"):
                check_package.check_startup(entries, sources)


class StrictChecks(unittest.TestCase):
    def test_missing_baseline_is_rejected_without_writing(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(regression, "OUTPUTS", Path(temporary)), patch.object(regression, "STRICT", True):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertFalse(regression.compare("missing", "new output", [], False, False))
            self.assertEqual(list(Path(temporary).iterdir()), [])

    def test_missing_lint_is_a_failure(self):
        with patch.object(regression, "STRICT", True), patch.dict(regression.os.environ, {"LUACHECK": ""}):
            with patch.object(regression.shutil, "which", return_value=None):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(regression.run_lint(), [False])


if __name__ == "__main__":
    unittest.main()
