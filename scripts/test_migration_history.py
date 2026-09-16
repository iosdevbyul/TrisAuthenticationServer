"""Offline planner safety checks; no database connections or credentials."""
import copy
import json
from pathlib import Path
import unittest
from uuid import UUID
from migration_history import INSPECT_SQL, plan

MIGRATIONS = json.loads((Path(__file__).resolve().parents[1] / 'Tests/Baselines/authentication-extraction.json').read_text())['migrations']


def fixture(count=11):
    return {'database': 'rename_fixture', 'rows': [
        {'id': str(UUID(int=i + 1)), 'name': 'LegacyAuthenticationHost.' + name.split('.')[1],
         'batch': 1 + i // 4, 'created_at': None, 'updated_at': None}
        for i, name in enumerate(MIGRATIONS[:count])
    ]}


class MigrationHistoryPlanningTests(unittest.TestCase):
    def test_inspection_is_read_only(self):
        self.assertIn('BEGIN READ ONLY', INSPECT_SQL)
        self.assertIn('to_jsonb(m)', INSPECT_SQL)
        self.assertNotIn('UPDATE', INSPECT_SQL)

    def test_partial_history_does_not_invent_rows(self):
        output = plan(fixture(5), 'LegacyAuthenticationHost', 5, MIGRATIONS)
        self.assertIn('changed <> 5', output)
        self.assertNotIn(MIGRATIONS[5], output)
        self.assertNotIn('INSERT INTO', output)
        self.assertNotIn('DELETE FROM', output)
        self.assertNotIn('CREATE TABLE', output)
        self.assertTrue(output.endswith('ROLLBACK;\n'))

    def test_full_snapshot_and_post_update_are_guarded(self):
        output = plan(fixture(), 'LegacyAuthenticationHost', 11, MIGRATIONS, commit=True)
        self.assertIn('LOCK TABLE public._fluent_migrations IN EXCLUSIVE MODE', output)
        self.assertEqual(output.count('IF actual IS DISTINCT FROM'), 2)
        self.assertIn('current_database()', output)
        self.assertIn('m.id = planned.id AND m.name = planned.old_name AND m.batch = planned.batch', output)
        self.assertNotIn('SET batch', output)
        self.assertTrue(output.endswith('COMMIT;\n'))

    def test_observed_count_is_mandatory_and_exact(self):
        for count in [-1, 0, 4, 6, True]:
            with self.subTest(count=count), self.assertRaises(ValueError):
                plan(fixture(5), 'LegacyAuthenticationHost', count, MIGRATIONS)

    def test_duplicate_ids_or_names_are_rejected(self):
        for field in ['id', 'name']:
            snapshot = fixture(2)
            snapshot['rows'][1][field] = snapshot['rows'][0][field]
            with self.subTest(field=field), self.assertRaises(ValueError):
                plan(snapshot, 'LegacyAuthenticationHost', 2, MIGRATIONS)

    def test_source_target_collision_is_rejected(self):
        snapshot = fixture(1)
        snapshot['rows'].append(dict(snapshot['rows'][0], id=str(UUID(int=50)), name=MIGRATIONS[0]))
        with self.assertRaises(ValueError):
            plan(snapshot, 'LegacyAuthenticationHost', 1, MIGRATIONS)

    def test_unknown_source_migration_is_rejected(self):
        snapshot = fixture(1)
        snapshot['rows'][0]['name'] = 'LegacyAuthenticationHost.UnknownMigration'
        with self.assertRaises(ValueError):
            plan(snapshot, 'LegacyAuthenticationHost', 1, MIGRATIONS)

    def test_unrelated_and_already_canonical_rows_are_preserved(self):
        snapshot = fixture(2)
        snapshot['rows'][1]['name'] = MIGRATIONS[1]
        snapshot['rows'].append(dict(snapshot['rows'][0], id=str(UUID(int=60)), name='OtherHost.OtherMigration'))
        before = copy.deepcopy(snapshot)
        output = plan(snapshot, 'LegacyAuthenticationHost', 1, MIGRATIONS)
        self.assertIn('OtherHost.OtherMigration', output)
        self.assertIn('changed <> 1', output)
        self.assertEqual(snapshot, before)

    def test_empty_or_already_renamed_history_has_no_update(self):
        for snapshot in [fixture(0), {'database': 'rename_fixture', 'rows': [dict(fixture(1)['rows'][0], name=MIGRATIONS[0])]}]:
            with self.assertRaises(ValueError):
                plan(snapshot, 'LegacyAuthenticationHost', 0, MIGRATIONS)

    def test_prefix_validation_and_quoting(self):
        for prefix in ['LegacyAuthenticationHost.', 'x; UPDATE users', MIGRATIONS[0].split('.')[0]]:
            with self.assertRaises(ValueError):
                plan(fixture(1), prefix, 1, MIGRATIONS)
        snapshot = fixture(1)
        snapshot['database'] = "quoted'db$migration_history$"
        output = plan(snapshot, 'LegacyAuthenticationHost', 1, MIGRATIONS)
        self.assertIn("quoted''db$migration_history$", output)
        self.assertIn('DO $migration_history_$', output)

    def test_invalid_row_is_rejected(self):
        for field, value in [('id', 'not-a-uuid'), ('id', 123), ('id', None), ('batch', 0), ('batch', True), ('name', None)]:
            snapshot = fixture(1)
            snapshot['rows'][0][field] = value
            with self.subTest(field=field), self.assertRaises((ValueError, TypeError)):
                plan(snapshot, 'LegacyAuthenticationHost', 1, MIGRATIONS)


if __name__ == '__main__':
    unittest.main()
