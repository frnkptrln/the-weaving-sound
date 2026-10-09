"""Launchers and render scripts must work headless, as a service user, and from any directory."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LauncherTests(unittest.TestCase):
    def test_temporal_binding_render_runs_without_display_or_browser_sandbox(self):
        # Regression: sclang links Qt WebEngine, which aborts when run as root
        # (containers, CI) unless its sandbox is disabled. render_piece.py sets
        # both variables for its sclang child; the shell renderer must too.
        text = (ROOT / "pieces/temporal-binding/render.sh").read_text()
        for variable in ("QT_QPA_PLATFORM", "QTWEBENGINE_DISABLE_SANDBOX"):
            with self.subTest(variable=variable):
                self.assertRegex(text, rf"(?m)^export {variable}=", f"render.sh must export {variable}")
        self.assertIn("export QT_QPA_PLATFORM=\"${QT_QPA_PLATFORM:-offscreen}\"", text)
        self.assertIn("export QTWEBENGINE_DISABLE_SANDBOX=\"${QTWEBENGINE_DISABLE_SANDBOX:-1}\"", text)

    def test_every_launcher_is_location_independent(self):
        for script in sorted(ROOT.glob("pieces/*/*.sh")):
            with self.subTest(script=str(script.relative_to(ROOT))):
                self.assertIn("BASH_SOURCE[0]", script.read_text())


if __name__ == "__main__":
    unittest.main()
