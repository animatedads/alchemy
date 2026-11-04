import importlib.util
import pathlib
import tempfile
import unittest

script = pathlib.Path(__file__).resolve().parents[1] / 'tools' / 'api_inventory.py'
spec = importlib.util.spec_from_file_location('api_inventory', script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class InventoryTests(unittest.TestCase):
    def make(self, content, name='dbus.cls'):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        p = pathlib.Path(td.name)
        (p / name).write_text(content, encoding='utf-8')
        return p

    def test_public_instance_class_methods_and_attribute(self):
        path = self.make('::class DBusProxy public\n::method foo\n::method bar class\n::attribute baz\n::method hidden private\n')
        inventory = mod.scan(path)
        self.assertIn('method|dbusproxy|foo|instance', inventory['public_signatures'])
        self.assertIn('method|dbusproxy|bar|class', inventory['public_signatures'])
        self.assertIn('attribute|dbusproxy|baz|instance', inventory['public_signatures'])
        self.assertNotIn('method|dbusproxy|hidden|instance', inventory['public_signatures'])

    def test_quoted_names_and_routines(self):
        inv = mod.scan(self.make('::class "DBus Service" public\n::method "strange-name"\n::routine example public\n'))
        self.assertIn('method|dbus service|strange-name|instance', inv['public_signatures'])
        self.assertIn('routine||example|', inv['public_signatures'])

    def test_requires_preserved_not_assumed_dependency(self):
        inv = mod.scan(self.make('::requires "dbus.cls"\n::requires "external.cls"\n'))
        self.assertEqual(inv['requires'], ['dbus.cls', 'external.cls'])

    def test_comments_ignored(self):
        inv = mod.scan(self.make('-- ::class Phantom\n/*\n::class Hidden\n*/\n::class Real\n'))
        self.assertEqual(inv['public_signatures'], ['class||real|'])

    def test_public_removal_identified(self):
        old = mod.scan(self.make('::class DBusProxy\n::method call\n::method signals\n'))
        new = mod.scan(self.make('::class DBusProxy\n::method call\n'))
        report = mod.compare(old, new)
        self.assertEqual(report['removed'], ['method|dbusproxy|signals|instance'])
        self.assertFalse(report['legacy_static_surface_preserved'])

    def test_public_addition_allowed(self):
        old = mod.scan(self.make('::class DBusProxy\n::method call\n'))
        new = mod.scan(self.make('::class DBusProxy\n::method call\n::method newmethod\n'))
        report = mod.compare(old, new)
        self.assertEqual(report['removed'], [])
        self.assertEqual(report['added'], ['method|dbusproxy|newmethod|instance'])
        self.assertTrue(report['legacy_static_surface_preserved'])

    def test_case_insensitive(self):
        old = mod.scan(self.make('::class DBusProxy\n::method CALL\n'))
        new = mod.scan(self.make('::class dbusproxy\n::method call\n'))
        self.assertEqual(mod.compare(old, new)['removed'], [])

    def test_duplicate_is_diagnostic(self):
        inv = mod.scan(self.make('::class DBusProxy\n::method call\n::method CALL\n'))
        self.assertEqual(inv['duplicates'], ['method|dbusproxy|call|instance'])

    def test_orphan_method_recorded(self):
        inv = mod.scan(self.make('::method call\n'))
        self.assertEqual(len(inv['diagnostics']), 1)

    def test_non_utf8_fails_closed(self):
        path = self.make('hi')
        (path / 'dbus.cls').write_bytes(b'\xff')
        with self.assertRaises(ValueError):
            mod.scan(path)

    def test_no_fake_native_qualification(self):
        old = mod.scan(self.make('::class DBusProxy\n'))
        new = mod.scan(self.make('::class DBusProxy\n'))
        r = mod.compare(old, new)
        self.assertEqual(r['native_binary_abi'], 'NOT_ASSESSED')
        self.assertEqual(r['runtime_compatibility'], 'NOT_ASSESSED')

if __name__ == '__main__':
    unittest.main()
