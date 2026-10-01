#!/usr/bin/env python3
import re
import sys
from pathlib import Path

DIFF_PATH = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/staging-public-schema-diff.log")
EXPECTED_PATH = Path("supabase/migrations/20260930130000_p15_t239_match_phone_source_fix.sql")

diff = DIFF_PATH.read_text()
expected = EXPECTED_PATH.read_text()

FUNCTION_RE = re.compile(
    r"create\s+or\s+replace\s+function\s+public\.match_import_customers\s*"
    r"\(.*?\)\s*"
    r"returns\s+table\s*\(.*?\)\s*"
    r"language\s+plpgsql\s*"
    r"security\s+definer\s*"
    r"set\s+search_path\s+(?:to|=)\s+.*?\s*"
    r"as\s+\$function\$(.*?)\$function\$\s*;",
    re.I | re.S,
)

def compact(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip().lower()

def function_contract(text: str):
    match = FUNCTION_RE.search(text)
    if not match:
        return None

    statement = match.group(0)
    body = compact(match.group(1))
    signature = re.search(
        r"create\s+or\s+replace\s+function\s+public\.match_import_customers\s*"
        r"\((.*?)\)\s*returns\s+table\s*\((.*?)\)\s*"
        r"language\s+plpgsql\s*security\s+definer\s*"
        r"set\s+search_path\s+(?:to|=)\s+(.*?)\s+as\s+\$function\$",
        statement,
        re.I | re.S,
    )
    if not signature:
        return None

    return {
        "args": compact(signature.group(1)),
        "returns": compact(signature.group(2)),
        "search_path": compact(signature.group(3).replace("'", "")),
        "body": body,
    }

actual = function_contract(diff)
expected = function_contract(expected)

if actual is None or expected is None:
    raise SystemExit("ERROR: match_import_customers definition was not found in both diff and repository migration.")

if actual != expected:
    print(f"Actual contract:   {actual}")
    print(f"Expected contract: {expected}")
    raise SystemExit("ERROR: match_import_customers is not repository-equivalent.")

filtered = re.sub(
    r'create extension if not exists "plpgsql_check" with schema "public";\s*',
    "",
    diff,
    flags=re.I,
)
filtered = FUNCTION_RE.sub("", filtered)
# migra emits this session-setting preamble when function DDL is present.
# It is a representation detail, not a persistent schema object.
filtered = re.sub(
    r"\bset\s+check_function_bodies\s*=\s*(?:off|false)\s*;\s*",
    "",
    filtered,
    flags=re.I,
)
filtered = re.sub(r"^--.*(?:\n|$)", "", filtered, flags=re.M)

remaining = re.sub(r"\s+", "", filtered)
if remaining:
    print(filtered)
    raise SystemExit("ERROR: unexpected public-schema drift.")

print("Verified known differences only: plpgsql_check extension, migra check_function_bodies preamble, and repository-equivalent match_import_customers.")
