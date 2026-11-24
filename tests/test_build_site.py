import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "build_site.py"
sys.path.insert(0, str(ROOT / "scripts"))
import build_site  # noqa: E402


class ListeningPageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix="listening-page-")
        cls.output = Path(cls.directory.name) / "index.html"
        subprocess.run([sys.executable, str(SCRIPT), "--output", str(cls.output), "--audio-base", "edition/"],
                       check=True, capture_output=True, text=True, cwd=ROOT)
        cls.page = cls.output.read_text(encoding="utf-8")
        cls.manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def test_every_rendered_piece_is_playable_and_every_session_is_listed(self):
        for piece in self.manifest["pieces"]:
            name = piece["name"]
            player = f'<audio controls preload="none" src="edition/{name}.mp3">'
            if name in build_site.OFF_THE_PAGE:
                self.assertNotIn(name, self.page, f"{name} is off the page but appears on it")
            elif piece.get("render"):
                self.assertIn(player, self.page, f"{name} has a render but no player")
                self.assertIn(f'href="edition/{name}.wav"', self.page)
            else:
                self.assertNotIn(player, self.page, f"{name} has no render but got a player")
                self.assertRegex(self.page, rf'<li><a href="[^"]+/pieces/{re.escape(name)}/">')

    def test_the_page_states_the_manifest_facts_not_others(self):
        rendered = [p for p in self.manifest["pieces"]
                    if p.get("render") and p["name"] not in build_site.OFF_THE_PAGE]
        self.assertEqual(self.page.count("<audio "), len(rendered))
        self.assertIn(f"{len(rendered)} pieces", self.page)
        for piece in rendered:
            minutes, seconds = divmod(int(round(piece["render"]["duration_seconds"])), 60)
            self.assertIn(f"{minutes}:{seconds:02d} · {piece['render']['channels']} ch", self.page)

    def test_the_page_is_self_contained(self):
        self.assertNotIn("<script", self.page)
        self.assertNotIn("<link", self.page)
        self.assertNotIn("@import", self.page)
        self.assertNotIn("fonts.googleapis", self.page)
        self.assertTrue(self.page.startswith("<!doctype html>"))
        self.assertIn('<meta name="viewport"', self.page)

    def test_pieces_off_the_page_exist_and_have_a_render(self):
        rendered = {p["name"] for p in self.manifest["pieces"] if p.get("render")}
        self.assertLessEqual(build_site.OFF_THE_PAGE, rendered,
                             "OFF_THE_PAGE names a piece the manifest does not render")

    def test_manifest_text_is_escaped(self):
        from datetime import datetime, timezone
        manifest = {"pieces": [
            {"name": "x&y", "status": "study", "focus": "a <b> & c",
             "render": {"duration_seconds": 61, "channels": 2, "sample_rate": 48000, "reproducible": False}},
            {"name": "session<1>", "status": "piece", "focus": "open & ended", "render": None},
        ]}
        page = build_site.render_page(manifest, "edition/", revision="test", now=datetime(2026, 1, 1, tzinfo=timezone.utc))
        self.assertIn("a &lt;b&gt; &amp; c", page)
        self.assertIn("open &amp; ended", page)
        self.assertIn("session&lt;1&gt;", page)
        self.assertNotIn("<b>", page)
        self.assertIn("1:01 · 2 ch", page)


if __name__ == "__main__":
    unittest.main()
