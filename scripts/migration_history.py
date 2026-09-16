"""Offline migration-history repair planning. This tool never connects to a database."""
import argparse
import json
from pathlib import Path
import re
from uuid import UUID

ROOT = Path(__file__).resolve().parents[1]
INSPECT_SQL = """BEGIN READ ONLY;
SET LOCAL TIME ZONE 'UTC';
SELECT jsonb_build_object(
    'database', current_database(),
    'rows', COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.id), '[]'::jsonb)
) FROM public._fluent_migrations AS m;
COMMIT;
"""


def sql_literal(value):
    # The generated transaction also fixes standard_conforming_strings.
    return "'" + value.replace("'", "''") + "'"


def plan(snapshot, source_prefix, expected_count, migrations, commit=False):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', source_prefix):
        raise ValueError('Source prefix must be the module name observed by SELECT, without a dot.')
    if not isinstance(snapshot, dict) or not isinstance(snapshot.get('database'), str) or not snapshot['database']:
        raise ValueError('Snapshot must contain the inspected database name.')
    rows = snapshot.get('rows')
    if not isinstance(rows, list):
        raise ValueError('Snapshot rows must be a JSON array.')
    if not migrations or len(set(migrations)) != len(migrations):
        raise ValueError('Invalid migration baseline.')
    targets = {}
    for name in migrations:
        prefix, suffix = name.split('.')
        if source_prefix == prefix:
            raise ValueError('Source and destination prefixes must differ.')
        targets[suffix] = name
    ids, names = set(), set()
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('name'), str) or not isinstance(row.get('id'), str):
            raise ValueError('Each history row needs id, name and batch.')
        row_id = str(UUID(row['id']))
        if row_id in ids or row['name'] in names:
            raise ValueError('Duplicate migration id/name; investigate before planning.')
        if type(row.get('batch')) is not int or row['batch'] < 1:
            raise ValueError('Migration batch must be a positive integer.')
        ids.add(row_id)
        names.add(row['name'])
    changes = []
    after = []
    for row in sorted(rows, key=lambda row: str(UUID(row['id']))):
        updated = dict(row)
        if row['name'].startswith(source_prefix + '.'):
            suffix = row['name'][len(source_prefix) + 1:]
            if suffix not in targets:
                raise ValueError('Unknown migration under the source prefix; manual investigation required.')
            target = targets[suffix]
            if target in names:
                raise ValueError('Both source and target migration exist; do not merge/delete history blindly.')
            updated['name'] = target
            changes.append((str(UUID(row['id'])), row['name'], target, row['batch']))
        after.append(updated)
    if type(expected_count) is not int or expected_count < 0 or len(changes) != expected_count:
        raise ValueError(f'Expected count does not match the inspected source rows ({len(changes)}).')
    if not changes:
        raise ValueError('No source rows to rename. No UPDATE is needed; inspect pending migrations separately.')
    before = sorted(rows, key=lambda row: str(UUID(row['id'])))
    before_json = sql_literal(json.dumps(before, ensure_ascii=True))
    after_json = sql_literal(json.dumps(after, ensure_ascii=True))
    values = ',\n        '.join(
        '(' + ', '.join([sql_literal(row_id) + '::uuid', sql_literal(old), sql_literal(new), str(batch)]) + ')'
        for row_id, old, new, batch in changes
    )
    # Exact snapshot comparison protects unrelated rows, ids, batches and timestamps too.
    # Default ROLLBACK allows a reviewed rehearsal; nothing runs automatically.
    end = 'COMMIT' if commit else 'ROLLBACK'
    tag = '$migration_history$'
    contents = before_json + after_json + values + sql_literal(snapshot['database'])
    while tag in contents:
        tag = tag[:-1] + '_$'
    return f"""-- Offline plan: {len(changes)} observed rows. Review against the SELECT snapshot.
-- Stop concurrent deployments/migrators before running. Default mode is a rehearsal.
BEGIN;
SET LOCAL standard_conforming_strings = on;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
LOCK TABLE public._fluent_migrations IN EXCLUSIVE MODE;
DO {tag}
DECLARE
    actual jsonb;
    changed integer;
BEGIN
    IF current_database() <> {sql_literal(snapshot['database'])} THEN
        RAISE EXCEPTION 'Database differs from the reviewed snapshot';
    END IF;
    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.id), '[]'::jsonb)
        INTO actual FROM public._fluent_migrations AS m;
    IF actual IS DISTINCT FROM {before_json}::jsonb THEN
        RAISE EXCEPTION 'Migration history changed since SELECT; export and review again';
    END IF;
    UPDATE public._fluent_migrations AS m SET name = planned.new_name
    FROM (VALUES
        {values}
    ) AS planned(id, old_name, new_name, batch)
    WHERE m.id = planned.id AND m.name = planned.old_name AND m.batch = planned.batch;
    GET DIAGNOSTICS changed = ROW_COUNT;
    IF changed <> {len(changes)} THEN
        RAISE EXCEPTION 'Unexpected UPDATE row count: %', changed;
    END IF;
    SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m.id), '[]'::jsonb)
        INTO actual FROM public._fluent_migrations AS m;
    IF actual IS DISTINCT FROM {after_json}::jsonb THEN
        RAISE EXCEPTION 'Unexpected history change; transaction must roll back';
    END IF;
END
{tag};
SELECT id, name, batch FROM public._fluent_migrations ORDER BY batch, name;
{end};
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('inspect', help='Print read-only SQL; does not execute it.')
    rename = commands.add_parser('plan', help='Print guarded SQL for an inspected snapshot; does not execute it.')
    rename.add_argument('snapshot', type=Path)
    rename.add_argument('--source-prefix', required=True)
    rename.add_argument('--expected-count', required=True, type=int)
    rename.add_argument('--commit', action='store_true', help='Emit COMMIT instead of the default ROLLBACK; still does not execute SQL.')
    args = parser.parse_args()
    if args.command == 'inspect':
        print(INSPECT_SQL, end='')
        return
    try:
        baseline = json.loads((ROOT / 'Tests/Baselines/authentication-extraction.json').read_text())
        snapshot = json.loads(args.snapshot.read_text())
        print(plan(snapshot, args.source_prefix, args.expected_count, baseline['migrations'], args.commit), end='')
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(2, f'Refusing to generate an UPDATE: {error}\n')


if __name__ == '__main__':
    main()
