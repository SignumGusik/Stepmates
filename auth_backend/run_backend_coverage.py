import os
import sys
from pathlib import Path

sys.argv.append("test")
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ios_auth.settings")

ROOT = Path(__file__).resolve().parent
SOURCE_FILES = [
    path for path in (ROOT / "api").glob("*.py")
    if not path.name.startswith("test_") and path.name != "tests.py"
]
SOURCE_PATHS = {str(path.resolve()): path for path in SOURCE_FILES}


def executable_lines(path):
    result = set()
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            result.add(index)
    return result


EXECUTABLE = {path: executable_lines(path) for path in SOURCE_FILES}
SEEN = {path: set() for path in SOURCE_FILES}


def localtrace(frame, event, arg):
    if event == "line":
        path = SOURCE_PATHS.get(os.path.realpath(frame.f_code.co_filename))
        if path is not None:
            SEEN[path].add(frame.f_lineno)
    return localtrace


def globaltrace(frame, event, arg):
    if event == "call" and os.path.realpath(frame.f_code.co_filename) in SOURCE_PATHS:
        return localtrace
    return None


def main():
    sys.path.insert(0, str(ROOT))

    sys.settrace(globaltrace)
    try:
        import django
        from django.core.management import call_command

        django.setup()
        call_command("test", "api", verbosity=0)
    finally:
        sys.settrace(None)

    total = sum(len(lines) for lines in EXECUTABLE.values())
    covered = sum(len(SEEN[path] & EXECUTABLE[path]) for path in SOURCE_FILES)
    percent = covered / total * 100 if total else 100

    print("\nBackend coverage")
    print(f"TOTAL {covered}/{total} ({percent:.2f}%)")
    for path in sorted(SOURCE_FILES):
        file_total = len(EXECUTABLE[path])
        file_covered = len(SEEN[path] & EXECUTABLE[path])
        file_percent = file_covered / file_total * 100 if file_total else 100
        print(f"{path.relative_to(ROOT)} {file_covered}/{file_total} {file_percent:.2f}%")

    if percent < 60:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
