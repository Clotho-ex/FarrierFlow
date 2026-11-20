import json
import subprocess
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCHEMES = ROOT / "FarrierFlow.xcodeproj/xcshareddata/xcschemes"


class XcodeRunConfigurationTests(unittest.TestCase):
    def test_normal_run_uses_production_while_tests_stay_in_debug(self):
        scheme = ET.parse(SCHEMES / "FarrierFlow.xcscheme").getroot()
        self.assertEqual(scheme.find("LaunchAction").get("buildConfiguration"), "Release")
        self.assertEqual(scheme.find("TestAction").get("buildConfiguration"), "Debug")
        self.assertIsNone(scheme.find("LaunchAction/StoreKitConfigurationFileReference"))

    def test_explicit_development_scheme_keeps_debug_and_storekit_testing(self):
        path = SCHEMES / "FarrierFlow Development.xcscheme"
        self.assertTrue(path.exists(), "Development must remain available through its own scheme.")
        scheme = ET.parse(path).getroot()
        self.assertEqual(scheme.find("LaunchAction").get("buildConfiguration"), "Debug")
        self.assertIsNotNone(scheme.find("LaunchAction/StoreKitConfigurationFileReference"))

    def test_release_build_resolves_the_existing_production_backend(self):
        result = subprocess.run(
            ["xcodebuild", "-showBuildSettings", "-project", "FarrierFlow.xcodeproj",
             "-scheme", "FarrierFlow", "-configuration", "Release", "-json"],
            cwd=ROOT, check=True, capture_output=True, text=True,
        )
        settings = next(
            target["buildSettings"] for target in json.loads(result.stdout)
            if target["target"] == "FarrierFlow"
        )
        self.assertEqual(settings.get("SUPABASE_URL"), "https://msyoovsdvvjjifrzzzbq.supabase.co")
        self.assertTrue(settings.get("SUPABASE_PUBLISHABLE_KEY", "").startswith("sb_publishable_"))
        self.assertEqual(settings.get("INFOPLIST_PREPROCESS"), "YES")
        self.assertIn("FARRIERFLOW_CLOUD_DELETION_ENABLED=1",
                      settings.get("INFOPLIST_PREPROCESSOR_DEFINITIONS", ""))


if __name__ == "__main__":
    unittest.main()
