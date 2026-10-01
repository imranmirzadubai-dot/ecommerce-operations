#!/usr/bin/env python3
import re
import sys
from pathlib import Path

DIFF_PATH = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/staging-public-schema-diff.log")
EXPECTED_PATH = Path("supabase/migrations/20260930130000_p15_t239_match_phone_source_fix.sql")

diff = DIFF_PATH.read_text()
expected = EXPECTED_PATH.read_text()

def function_body(text):
    match = re.search(
        r"create\s+or\s+replace\s+function\s+public\.match_import_customers.*?"
        r"\$function\$(.*?)\$function\$\s*;",
        text,
        re.I | re.S,
    )
    return re.sub(r"\s+", " ", match.group(1)).strip().lower() if match else None

if function_body(diff) != function_body(expected):
    raise SystemExit("ERROR: match_import_customers is not repository-equivalent.")

filtered = re.sub(
    r'create extension if not exists "plpgsql_check" with schema "public";\s*',
    "",
    diff,
    flags=re.I,
)
filtered = re.sub(
    r"create\s+or\s+replace\s+function\s+public\.match_import_customers.*?"
    r"\$function\$.*?\$function\$\s*;",
    "",
    filtered,
    flags=re.I | re.S,
)
filtered = re.sub(r"^--.*(?:\n|$)", "", filtered, flags=re.M)

if re.sub(r"\s+", "", filtered):
    print(filtered)
    raise SystemExit("ERROR: unexpected public-schema drift.")

print("Verified known differences only.")
