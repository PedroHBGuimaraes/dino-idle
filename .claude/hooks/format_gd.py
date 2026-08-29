"""PostToolUse hook: auto-formata (gdformat) e linta (gdlint) o .gd que acabou
de ser editado/escrito. Não bloqueia nada — só formata e devolve os
problemas de estilo (se houver) como contexto adicional pro Claude."""

import json
import os
import subprocess
import sys


def main() -> None:
    data = json.load(sys.stdin)
    file_path = data.get("tool_input", {}).get("file_path", "")

    if not file_path.endswith(".gd") or not os.path.exists(file_path):
        return

    subprocess.run(["gdformat", file_path], check=False)
    result = subprocess.run(
        ["gdlint", file_path], capture_output=True, text=True, check=False
    )

    if result.returncode != 0:
        output = (result.stdout + result.stderr).strip()
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PostToolUse",
                        "additionalContext": (
                            f"gdlint encontrou problemas em {file_path}:\n{output}"
                        ),
                    }
                }
            )
        )


if __name__ == "__main__":
    main()
