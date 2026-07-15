"""
重新生成细沙（浅）图片 — Sand1
=================================
尺寸: 256x64 (宽扁条，用于缸底铺设)

依赖：
  - ComfyUI 运行在 http://127.0.0.1:8188
  - Text2Image.json 工作流模板
"""

import json
import random
import shutil
import time
from pathlib import Path
from urllib import request as url_request
from urllib.error import URLError

COMFYUI_URL = "http://127.0.0.1:8188"
WORKFLOW_PATH = Path(__file__).parent / "Text2Image.json"
OUTPUT_DIR = Path(__file__).parent / "output"
GAME_PATH = Path(__file__).parent.parent / "assets" / "decorations" / "deco_substrate_sand_1.png"


def load_workflow(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def queue_prompt(workflow: dict):
    payload = json.dumps({"prompt": workflow}).encode("utf-8")
    req = url_request.Request(f"{COMFYUI_URL}/prompt", data=payload, headers={"Content-Type": "application/json"})
    resp = url_request.urlopen(req, timeout=30)
    return json.loads(resp.read()).get("prompt_id")


def get_history(prompt_id: str) -> dict:
    try:
        resp = url_request.urlopen(f"{COMFYUI_URL}/history/{prompt_id}", timeout=10)
        return json.loads(resp.read())
    except Exception:
        return {}


def wait_for_completion(prompt_id: str, timeout: int = 120) -> dict:
    waited = 0
    while waited < timeout:
        history = get_history(prompt_id)
        if prompt_id in history:
            return history[prompt_id]
        time.sleep(2)
        waited += 2
    raise TimeoutError(f"任务 {prompt_id} 超时")


def get_output_files(history_entry: dict) -> list[tuple[str, str, str]]:
    results = []
    for node_id, node_out in history_entry.get("outputs", {}).items():
        for img_data in node_out.get("images", []):
            if img_data.get("type", "output") == "temp":
                continue
            results.append((img_data["filename"], img_data.get("subfolder", ""), img_data.get("type", "output")))
    return results


def download_image(filename: str, subfolder: str, img_type: str, save_path: Path) -> bool:
    import urllib.parse
    query = urllib.parse.urlencode({"filename": filename, "subfolder": subfolder, "type": img_type})
    resp = url_request.urlopen(f"{COMFYUI_URL}/view?{query}", timeout=30)
    save_path.parent.mkdir(parents=True, exist_ok=True)
    with open(save_path, "wb") as f:
        f.write(resp.read())
    return True


def main():
    print("=" * 50)
    print("  重新生成: 细沙（浅）(Sand1)")
    print("  尺寸: 256 x 64")
    print("=" * 50)

    workflow = load_workflow(WORKFLOW_PATH)
    workflow = json.loads(json.dumps(workflow))  # 深拷贝

    # 设置 prompt
    workflow["72:67"]["inputs"]["text"] = (
        "pixel art deco, substrate, light beige fine sand texture, "
        "#00ff00 green background, game asset, centered, flat lighting"
    )
    # 设置尺寸 256x64
    workflow["72:68"]["inputs"]["width"] = 256
    workflow["72:68"]["inputs"]["height"] = 64
    # 设置文件名前缀
    workflow["75"]["inputs"]["filename_prefix"] = "deco_substrate_sand_1"
    # 随机种子
    workflow["72:70"]["inputs"]["seed"] = random.randint(0, 2**63 - 1)

    # 检查 ComfyUI
    print("[*] 检查 ComfyUI…")
    url_request.urlopen(f"{COMFYUI_URL}/queue", timeout=5)
    print("  ✓ 连接成功")

    # 提交任务
    print("[*] 提交工作流…")
    prompt_id = queue_prompt(workflow)
    print(f"  ✓ 已提交, prompt_id={prompt_id[:8]}…")

    # 等待完成
    print("[*] 等待生成完成…")
    history_entry = wait_for_completion(prompt_id)
    files = get_output_files(history_entry)
    if not files:
        print("✗ 没有找到输出文件")
        return

    fname, subfolder, img_type = files[0]
    print(f"  ✓ 生成: {fname}")

    # 下载到 output 目录
    local_path = OUTPUT_DIR / "deco_substrate_sand_1.png"
    download_image(fname, subfolder, img_type, local_path)
    print(f"  ✓ 已保存: {local_path}")

    # 复制到游戏资源目录
    shutil.copy2(local_path, GAME_PATH)
    print(f"  ✓ 已复制到游戏资源: {GAME_PATH}")

    # 删除旧的 .import 文件让 Godot 重新导入
    import_path = GAME_PATH.with_suffix(GAME_PATH.suffix + ".import")
    if import_path.exists():
        import_path.unlink()
        print(f"  ✓ 已删除旧 .import，Godot 将重新导入")

    print(f"\n{'='*50}")
    print(f"  完成!")
    print(f"{'='*50}")


if __name__ == "__main__":
    main()
