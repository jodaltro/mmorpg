"""Prepare private Nakama schemas using PostgreSQL, without touching Supabase internals.

Requires psql and Nakama 3.41.0. Reads DATABASE_URL from an ignored admin env file.
Outputs runtime/migration URLs to an ignored file outside the checkout. Never prints URLs.
--reset deletes the old game schema and the private Nakama schema (all their data).
Does not change the running server or migrate the Go command log.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
from urllib.parse import parse_qsl, quote, urlencode, urlsplit, urlunsplit, unquote

ROOT = Path(__file__).resolve().parents[1]


def literal(value):
    return "'" + value.replace("'", "''") + "'"


def prepare(args):
    output = Path(args.output).resolve()
    if output.is_relative_to(ROOT):
        raise ValueError("Secret output must be outside the checkout")
    values = {}
    for line in Path(args.admin_env).read_text(encoding="utf-8-sig").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    source = urlsplit(values[args.variable])
    query = dict(parse_qsl(source.query))
    if args.ca:
        query["sslrootcert"] = str(Path(args.ca).resolve())
    if query.get("sslmode") != "verify-full" and source.hostname not in ("127.0.0.1", "localhost", "::1"):
        raise ValueError("Remote PostgreSQL requires sslmode=verify-full")
    connection = os.environ.copy()
    # libpq environment keeps credentials out of process arguments.
    connection.update(PGHOST=source.hostname, PGPORT=str(source.port or 5432),
                      PGUSER=unquote(source.username), PGPASSWORD=unquote(source.password or ""),
                      PGDATABASE=unquote(source.path.lstrip("/")), PGCONNECT_TIMEOUT="10")
    for key, value in query.items():
        if key in ("sslmode", "sslrootcert"):
            connection["PG" + key.upper()] = value

    def sql(statement):
        result = subprocess.run([args.psql, "-X", "-v", "ON_ERROR_STOP=1", "-At"],
                                input=statement, env=connection, capture_output=True, text=True)
        if result.returncode:
            diagnostic = result.stderr
            for secret in [values[args.variable], source.hostname, unquote(source.password or ""), *passwords.values()]:
                if secret:
                    diagnostic = diagnostic.replace(secret, "[redacted]")
            output.with_suffix(".prepare.log").write_text(diagnostic, encoding="utf-8")
            raise RuntimeError("PostgreSQL preparation failed; no connection details printed")
        return result.stdout

    # Finish preparing the SQL before doing any destructive operation.
    passwords = {role: secrets.token_urlsafe(32) for role in ("hospedeiro_migrator", "hospedeiro_runtime")}
    statements = ["BEGIN; SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='30s';"]
    if args.reset:
        statements += ["DROP SCHEMA IF EXISTS game CASCADE;", "DROP SCHEMA IF EXISTS nakama CASCADE;"]
    for role, password in passwords.items():
        statements += [f"DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='{role}') THEN CREATE ROLE {role} LOGIN; END IF; END $$;",
                       f"DO $$ BEGIN IF EXISTS (SELECT FROM pg_roles WHERE rolname='{role}' AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)) THEN RAISE EXCEPTION 'Existing application role is privileged'; END IF; END $$;",
                       f"ALTER ROLE {role} LOGIN PASSWORD {literal(password)};"]
    statements += [
        "GRANT hospedeiro_migrator TO CURRENT_USER;",
        "CREATE SCHEMA IF NOT EXISTS nakama AUTHORIZATION hospedeiro_migrator;",
        "ALTER SCHEMA nakama OWNER TO hospedeiro_migrator;",
        "CREATE SCHEMA IF NOT EXISTS extensions;",
        "CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;",
        "GRANT USAGE ON SCHEMA extensions TO hospedeiro_migrator,hospedeiro_runtime;",
        "REVOKE ALL ON SCHEMA nakama FROM PUBLIC, anon, authenticated;" if args.supabase else "REVOKE ALL ON SCHEMA nakama FROM PUBLIC;",
        "GRANT USAGE ON SCHEMA nakama TO hospedeiro_runtime;",
        "ALTER ROLE hospedeiro_migrator SET search_path=nakama,extensions;",
        "ALTER ROLE hospedeiro_runtime SET search_path=nakama,extensions;",
        "ALTER DEFAULT PRIVILEGES FOR ROLE hospedeiro_migrator IN SCHEMA nakama REVOKE ALL ON TABLES FROM PUBLIC;",
        "ALTER DEFAULT PRIVILEGES FOR ROLE hospedeiro_migrator IN SCHEMA nakama GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO hospedeiro_runtime;",
        "ALTER DEFAULT PRIVILEGES FOR ROLE hospedeiro_migrator IN SCHEMA nakama GRANT USAGE,SELECT ON SEQUENCES TO hospedeiro_runtime;",
        "ALTER DEFAULT PRIVILEGES FOR ROLE hospedeiro_migrator IN SCHEMA nakama REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;",
        "COMMIT;",
    ]
    # Save generated credentials first, so a migration failure cannot lose them.
    urls = {}
    for role, password in passwords.items():
        host = source.hostname
        if ":" in host:
            host = f"[{host}]"
        address = f"{role}:{quote(password, safe='')}@{host}:{source.port or 5432}"
        urls[role] = urlunsplit(("postgres", address, source.path, urlencode(dict(query, search_path="nakama,extensions")), ""))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("HOSPEDEIRO_NAKAMA_DATABASE_URL=" + urls["hospedeiro_runtime"] +
                      "\nHOSPEDEIRO_NAKAMA_MIGRATION_URL=" + urls["hospedeiro_migrator"] + "\n", encoding="utf-8")
    os.chmod(output, 0o600)
    sql("\n".join(statements))
    with tempfile.TemporaryDirectory(dir=output.parent) as directory:
        config = Path(directory) / "migration.json"
        config.write_text(json.dumps({"database": {"address": [urls["hospedeiro_migrator"]], "max_open_conns": 2, "max_idle_conns": 1}}))
        os.chmod(config, 0o600)
        result = subprocess.run([args.nakama, "migrate", "up", "--config", str(config)], capture_output=True)
        diagnostic = (result.stdout + result.stderr).decode("utf-8", errors="replace")
        for secret in [*urls.values(), *passwords.values(), source.hostname]:
            diagnostic = diagnostic.replace(secret, "[redacted]")
        output.with_suffix(".migration.log").write_text(diagnostic, encoding="utf-8")
        if result.returncode:
            raise RuntimeError("Official Nakama migration failed; credentials saved outside checkout")
    sql("GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA nakama TO hospedeiro_runtime; GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA nakama TO hospedeiro_runtime;")
    if args.supabase:
        sql("REVOKE ALL ON ALL TABLES IN SCHEMA nakama FROM anon,authenticated; REVOKE ALL ON ALL SEQUENCES IN SCHEMA nakama FROM anon,authenticated;")
    print("Private Nakama schema prepared; runtime and migration credentials saved outside checkout.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--admin-env", required=True)
    parser.add_argument("--variable", default="DATABASE_URL")
    parser.add_argument("--output", required=True)
    parser.add_argument("--ca")
    parser.add_argument("--reset", action="store_true")
    parser.add_argument("--supabase", action="store_true", help="Revoke access from Supabase API roles as well")
    parser.add_argument("--psql", default="psql")
    parser.add_argument("--nakama", default="nakama")
    try:
        prepare(parser.parse_args())
    except (ValueError, KeyError, OSError, RuntimeError) as error:
        # Never include driver/config exceptions that may embed credentials.
        detail = str(error) if isinstance(error, (RuntimeError, ValueError)) else type(error).__name__
        raise SystemExit("Database preparation did not complete: " + detail)
