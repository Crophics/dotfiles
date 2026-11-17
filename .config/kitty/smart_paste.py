import subprocess

from kittens.tui.handler import result_handler
from kitty.boss import Boss


def main(args: list[str]) -> None:
    pass


@result_handler(no_ui=True)
def handle_result(
    args: list[str], answer: str, target_window_id: int, boss: Boss
) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    try:
        types = subprocess.run(
            ["wl-paste", "-l"], capture_output=True, text=True, timeout=2
        ).stdout.split()
    except Exception:
        types = []
    has_image = any(t.startswith("image/") for t in types)
    has_text = any(t.startswith("text/") or t in ("STRING", "UTF8_STRING") for t in types)
    if has_image and not has_text:
        w.send_key("ctrl+v")
    else:
        boss.paste_from_clipboard()
