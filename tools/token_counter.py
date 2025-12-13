# tools/token_counter.py
import sys, json, pathlib
import tiktoken

ENC = tiktoken.get_encoding("cl100k_base")  # Claude-compatible approx

def count_text(text: str) -> int:
    return len(ENC.encode(text or ""))

def count_messages(messages) -> int:
    total = 0
    for m in messages:
        total += count_text(m.get("content", ""))
    return total

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python tools/token_counter.py <file.txt> [more files...]")
        print("  python tools/token_counter.py --json messages.json")
        sys.exit(1)

    if sys.argv[1] == "--json":
        data = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8", errors="ignore"))
        n = count_messages(data)
        print(f"TOTAL tokens (approx): {n}")
    else:
        total = 0
        for p in sys.argv[1:]:
            txt = pathlib.Path(p).read_text(encoding="utf-8", errors="ignore")
            n = count_text(txt)
            total += n
            print(f"{p}: {n}")
        print(f"TOTAL: {total}")
