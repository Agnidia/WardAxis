//
//  0002_CreateConfiguration.swift
//
//  Created on 12.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

extension Migration {
    /// The live configuration, its gapless version and its change log.
    ///
    /// Statement-level triggers on `config_entries` bump the single `config_version` row,
    /// append one `config_changes` row and notify `config_changes`, all inside the writer's
    /// transaction. The row update rolls back with a failed write and its row lock
    /// serializes writers, so versions are contiguous and commit in version order; a
    /// `SEQUENCE` would leave a gap on rollback. One firing statement is one version, and
    /// a statement that changes no value bumps nothing.
    ///
    /// The notification carries only the version: it wakes the relay, which reads the
    /// change log, so a lost notification or the 8000-byte payload limit loses nothing.
    static let createConfiguration0002: Migration = .init(
        version: 2,
        name: "create_configuration",
        statements: [
            """
            CREATE TABLE config_entries (
                key   text  PRIMARY KEY CHECK (char_length(key) BETWEEN 1 AND 256),
                value jsonb NOT NULL
            )
            """,
            """
            CREATE TABLE config_version (
                singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
                version   bigint  NOT NULL CHECK (version >= 0)
            )
            """,
            "INSERT INTO config_version (singleton, version) VALUES (true, 0)",
            """
            CREATE TABLE config_changes (
                version      bigint      PRIMARY KEY CHECK (version > 0),
                changed      jsonb       NOT NULL CHECK (jsonb_typeof(changed) = 'object'),
                removed      text[]      NOT NULL,
                committed_at timestamptz NOT NULL DEFAULT now()
            )
            """,
            // Each branch reads only its own transition tables: a DELETE trigger has no
            // `new_rows`. Empty aggregates are NULL, hence the COALESCE. An UPDATE that
            // renames a key reports the new key as changed and the old one as removed.
            """
            CREATE FUNCTION config_record_change() RETURNS trigger
            LANGUAGE plpgsql AS $$
            DECLARE
                changed_values jsonb;
                removed_keys   text[];
                next_version   bigint;
            BEGIN
                IF TG_OP = 'INSERT' THEN
                    SELECT COALESCE(jsonb_object_agg(n.key, n.value), '{}'::jsonb)
                    INTO changed_values
                    FROM new_rows AS n;
                    removed_keys := '{}'::text[];
                ELSIF TG_OP = 'UPDATE' THEN
                    SELECT COALESCE(jsonb_object_agg(n.key, n.value), '{}'::jsonb)
                    INTO changed_values
                    FROM new_rows AS n
                    LEFT JOIN old_rows AS o ON o.key = n.key
                    WHERE o.key IS NULL OR o.value IS DISTINCT FROM n.value;
                    SELECT COALESCE(array_agg(o.key ORDER BY o.key), '{}'::text[])
                    INTO removed_keys
                    FROM old_rows AS o
                    LEFT JOIN new_rows AS n ON n.key = o.key
                    WHERE n.key IS NULL;
                ELSE
                    changed_values := '{}'::jsonb;
                    SELECT COALESCE(array_agg(o.key ORDER BY o.key), '{}'::text[])
                    INTO removed_keys
                    FROM old_rows AS o;
                END IF;
                
                IF changed_values = '{}'::jsonb AND cardinality(removed_keys) = 0 THEN
                    RETURN NULL;
                END IF;
                
                UPDATE config_version SET version = version + 1 WHERE singleton
                RETURNING version INTO next_version;
                INSERT INTO config_changes (version, changed, removed)
                VALUES (next_version, changed_values, removed_keys);
                PERFORM pg_notify('config_changes', next_version::text);
                RETURN NULL;
            END
            $$
            """,
            """
            CREATE TRIGGER config_entries_record_insert
            AFTER INSERT ON config_entries
            REFERENCING NEW TABLE AS new_rows
            FOR EACH STATEMENT EXECUTE FUNCTION config_record_change()
            """,
            """
            CREATE TRIGGER config_entries_record_update
            AFTER UPDATE ON config_entries
            REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
            FOR EACH STATEMENT EXECUTE FUNCTION config_record_change()
            """,
            """
            CREATE TRIGGER config_entries_record_delete
            AFTER DELETE ON config_entries
            REFERENCING OLD TABLE AS old_rows
            FOR EACH STATEMENT EXECUTE FUNCTION config_record_change()
            """,
            // TRUNCATE fires no row or transition-table triggers, so it would change the
            // configuration without a version.
            """
            CREATE FUNCTION config_reject_truncate() RETURNS trigger
            LANGUAGE plpgsql AS $$
            BEGIN
                RAISE EXCEPTION 'TRUNCATE config_entries is not allowed; DELETE the rows so the change gets a version';
            END
            $$
            """,
            """
            CREATE TRIGGER config_entries_reject_truncate
            BEFORE TRUNCATE ON config_entries
            FOR EACH STATEMENT EXECUTE FUNCTION config_reject_truncate()
            """
        ]
    )
}
