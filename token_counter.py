# tools/token_counter.py
# Approximate token counting for Claude using OpenAI's cl100k_base encoding.
# Keep a 10–15% margin below your target window to be safe.

import sys, json, pathlib
import tiktoken

ENC = tiktoken.get_encoding("cl100k_base")  # robust, widely used approximation

def count_text(text: str) -> int:
    return len(ENC.encode(text or ""))

def count_messages(messages) -> int:
    """
    messages = [
      {"role": "system", "content": "..."}, 
      {"role": "user", "content": "..."}, ...
    ]
    """
    total = 0
    for m in messages:
        total += count_text(m.get("content", ""))
    return total

def truncate_messages(messages, max_tokens: int):
    """Keep system first, then newest turns until max_tokens is hit."""
    sys_msgs = [m for m in messages if m.get("role") == "system"]
    rest = [m for m in messages if m.get("role") != "system"]
    kept = []
    total = sum(count_text(m.get("content", "")) for m in sys_msgs)

    for m in reversed(rest):
        t = count_text(m.get("content", ""))
        if total + t <= max_tokens:
            kept.append(m)
            total += t
        else:
            break

    return sys_msgs + list(reversed(kept)), total

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python tools/token_counter.py <file.txt> [more files...]")
        print("  python tools/token_counter.py --json messages.json  # list of {role,content}")
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
