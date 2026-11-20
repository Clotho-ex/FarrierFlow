import importlib.util
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "release_sync", Path(__file__).resolve().parents[1] / "validate-release-sync.py"
)
release_sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_sync)


class ReleaseSyncConfigurationTests(unittest.TestCase):
    project = "abcdefghijklmnopqrst"

    def info(self):
        return {
            "CFBundleIdentifier": "com.farrierflow.yusufcan.FarrierFlow",
            "SUPABASE_URL": f"https://{self.project}.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_" + "x" * 32,
            "SUPABASE_CLOUD_DELETION_ENABLED": True,
        }

    def test_accepts_resolved_production_configuration(self):
        self.assertEqual(release_sync.validate(self.info(), self.project), [])

    def test_rejects_development_even_when_it_matches_the_expected_host(self):
        info = self.info()
        info["SUPABASE_URL"] = f"https://{release_sync.DEVELOPMENT_PROJECT}.supabase.co"
        self.assertTrue(release_sync.validate(info, release_sync.DEVELOPMENT_PROJECT))

    def test_rejects_unresolved_empty_or_privileged_client_settings(self):
        for field, value in [
            ("SUPABASE_URL", ""),
            ("SUPABASE_URL", "$(SUPABASE_URL)"),
            ("SUPABASE_URL", "https://anotherproject.supabase.co"),
            ("SUPABASE_PUBLISHABLE_KEY", ""),
            ("SUPABASE_PUBLISHABLE_KEY", "$(SUPABASE_PUBLISHABLE_KEY)"),
            ("SUPABASE_PUBLISHABLE_KEY", "sb_secret_" + "x" * 32),
            ("CFBundleIdentifier", "com.example.other"),
        ]:
            with self.subTest(field=field, value=value):
                info = self.info()
                info[field] = value
                self.assertTrue(release_sync.validate(info, self.project))

    def test_requires_explicit_boolean_deletion_enablement(self):
        for value in [None, False, "true", "YES", 1]:
            with self.subTest(value=value):
                info = self.info()
                info["SUPABASE_CLOUD_DELETION_ENABLED"] = value
                self.assertTrue(release_sync.validate(info, self.project))


if __name__ == "__main__":
    unittest.main()
