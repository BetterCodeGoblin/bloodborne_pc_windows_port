import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'scripts'))
import patches  # noqa: E402

XML = Path(__file__).resolve().parent.parent / 'patches/Bloodborne.xml'
SEGMENTS = [(0, 0x10000000)]  # every patch address inside the eboot


class UltrawideTest(unittest.TestCase):
    def test_hud_width_matches_community_patches(self):
        self.assertEqual(patches.hud_width((1920, 1080)), 1920)
        self.assertEqual(patches.hud_width((2560, 1080)), 2560)
        self.assertEqual(patches.hud_width((3440, 1440)), 2560)
        self.assertEqual(patches.hud_width((5120, 2160)), 2560)
        self.assertEqual(patches.hud_width((3840, 1080)), 3840)

    def test_wide_output(self):
        self.assertFalse(patches.wide_output((2560, 1440)))
        self.assertFalse(patches.wide_output((1920, 1200)))
        self.assertTrue(patches.wide_output((3440, 1440)))

    def test_21_9_writes_equal_community_patch(self):
        sizes = {patches.SCENE_WIDTH, patches.SCENE_HEIGHT, patches.UI_WIDTH, patches.UI_HEIGHT}
        for output, name in [((2560, 1080), 'Resolution Patch 2560x1080 (21:9)'),
                             ((3440, 1440), 'Resolution Patch 3440x1440 (21:9)')]:
            ours, hud = patches.aspect_writes(XML, output, '01.09', SEGMENTS)
            ref = [(o, d) for o, d in patches.compile_patches(XML, [name], '01.09', SEGMENTS)
                   if o not in sizes]
            self.assertEqual(hud, 2560)
            self.assertEqual(dict(ours), dict(ref), name)

    def test_aspect_float(self):
        ours, _ = patches.aspect_writes(XML, (3440, 1440), '01.09', SEGMENTS)
        value, = struct.unpack('<f', dict(ours)[patches.ASPECT_FLOAT])
        self.assertAlmostEqual(value, 3440 / 1440, places=5)


if __name__ == '__main__':
    unittest.main()
