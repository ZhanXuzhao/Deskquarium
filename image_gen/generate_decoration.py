"""
生成装饰物图片
================
用法：
  python generate_decoration.py <装饰名>    # 如 Sand1, Anubias
  python generate_decoration.py             # 交互式选择

依赖：
  - ComfyUI 运行在 http://127.0.0.1:8188
  - Text2Image.json 工作流模板
"""

import json
import os
import random
import shutil
import sys
import time
from pathlib import Path
from typing import Optional
from urllib import request as url_request
from urllib.error import URLError

# ===================== 配置 =====================

COMFYUI_URL = "http://127.0.0.1:8188"
WORKFLOW_PATH = Path(__file__).parent / "Text2Image.json"
OUTPUT_DIR = Path(__file__).parent / "output"
GAME_ASSETS_DIR = Path(__file__).parent.parent / "assets" / "decorations"

# 装饰列表：(中文名, 英文名(代码), prompt描述, 生图宽度, 生图高度)
DECO_LIST = [
    ("水榕",       "Anubias",        "aquatic plant Anubias, broad dark green leaves on rhizome", 256, 256),
    ("椒草",       "Bucephalandra",  "aquatic plant Bucephalandra, small round leaves in layered rosette", 256, 256),
    ("水蕴草",     "Hydrilla",       "aquatic plant Hydrilla, long thin green stems with tiny leaves", 128, 256),
    ("莫斯 1",     "Moss1",          "moss ball, round fluffy green moss cluster", 256, 256),
    ("莫斯 2",     "Moss2",          "moss carpet, flat spreading green moss patch", 256, 128),
    ("莫斯 3",     "Moss3",          "moss on driftwood, green moss clump attached to wood", 256, 256),
    ("莫斯 4",     "Moss4",          "moss wall, vertical green moss coverage", 256, 256),
    ("水兰",       "Vallisneria",    "aquatic plant Vallisneria, long ribbon-like green leaves flowing upward", 128, 256),
    ("珊瑚（红）", "Coral1",         "bright red branching coral", 256, 256),
    ("珊瑚（蓝）", "Coral2",         "bright blue branching coral", 256, 256),
    ("珊瑚（紫）", "Coral3",         "purple branching coral", 256, 256),
    ("珊瑚骨（大）","CoralBone1",    "large white coral bone fragment, porous texture", 256, 256),
    ("珊瑚骨（小）","CoralBone2",    "small white coral bone piece", 256, 256),
    ("海螺",       "Conch",          "seashell, conch spiral shell, light brown and white stripes", 256, 256),
    ("贝壳",       "Seashell",       "seashell, scallop shell with ridges, light pink and white", 256, 256),
    ("虾屋",       "ShrimpAve",      "shrimp hideout, small clay cave with round entrance", 256, 256),
    ("细沙（浅）", "Sand1",          "substrate, light beige fine sand texture", 256, 64),
    ("细沙（深）", "Sand2",          "substrate, dark brown fine sand texture", 256, 64),
]


# ===================== 查找 =====================

def find_deco(query: str) -> Optional[tuple]:
    if query.isdigit():
        idx = int(query) - 1
        if 0 <= idx < len(DECO_LIST):
            return (idx,) + DECO_LIST[idx]
    for idx, (cn, en, desc, w, h) in enumerate(DECO_LIST):
        if query == cn or query.lower() == en.lower():
            return (idx, cn, en, desc, w, h)
    for idx, (cn, en, desc, w, h) in enumerate(DECO_LIST):
        if query.lower() in cn.lower() or query.lower() in en.lower():
            return (idx, cn, en, desc, w, h)
    return None


def print_menu():
    print(f"\n{'='*55}")
    print(f"  可选择的装饰 ({len(DECO_LIST)} 种)")
    print(f"{'='*55}")
    for i, (cn, en, _, w, h) in enumerate(DECO_LIST, 1):
        print(f"  {i:2d}. {cn} ({en}) -> {w}x{h}")
    print(f"{'='*55}")


def pick_interactive():
    print_menu()
    while True:
        try:
            choice = input("\n请输入序号或名称 (直接回车取消): ").strip()
            if not choice:
                return None
            result = find_deco(choice)
            if result:
                return result
            print("  ✗ 未找到匹配，请重新输入")
        except (EOFError, KeyboardInterrupt):
            return None


# ===================== ComfyUI API =====================

def load_workflow(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def update_workflow(workflow: dict, cn: str, en: str, desc: str, width: int, height: int) -> dict:
    workflow = json.loads(json.dumps(workflow))
    prompt_text = (
        f"pixel art deco, {desc}, "
        f"#00ff00 green background, game asset, centered, flat lighting"
    )
    workflow["72:67"]["inputs"]["text"] = prompt_text
    workflow["72:68"]["inputs"]["width"] = width
    workflow["72:68"]["inputs"]["height"] = height
    # ComfyUI 输出前缀（实际文件会加 _00001 等后缀）
    prefix = f"deco_{en.lower()}"
    if "75" in workflow:
        workflow["75"]["inputs"]["filename_prefix"] = prefix
    seed = random.randint(0, 2**63 - 1)
    workflow["72:70"]["inputs"]["seed"] = seed
    return workflow


def queue_prompt(workflow: dict) -> Optional[str]:
    payload = json.dumps({"prompt": workflow}).encode("utf-8")
    req = url_request.Request(f"{COMFYUI_URL}/prompt", data=payload, headers={"Content-Type": "application/json"})
    try:
        resp = url_request.urlopen(req, timeout=30)
        return json.loads(resp.read()).get("prompt_id")
    except URLError as e:
        print(f"  ✗ 提交失败: {e}")
        return None


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
    print(f"  ⚠ 任务 {prompt_id} 超时")
    return {}


def get_output_filenames(history_entry: dict) -> list[tuple[str, str, str]]:
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
    view_url = f"{COMFYUI_URL}/view?{query}"
    try:
        resp = url_request.urlopen(view_url, timeout=30)
        save_path.parent.mkdir(parents=True, exist_ok=True)
        with open(save_path, "wb") as f:
            f.write(resp.read())
        return True
    except Exception as e:
        print(f"  ✗ 下载失败 {filename}: {e}")
        return False


# ===================== 主流程 =====================

def generate(deco_cn: str, deco_en: str, deco_desc: str, width: int, height: int, index: int, total: int) -> Optional[Path]:
    print(f"\n[{index}/{total}] {deco_cn} ({deco_en}) -> {width}x{height}")

    workflow_template = load_workflow(WORKFLOW_PATH)
    workflow = update_workflow(workflow_template, deco_cn, deco_en, deco_desc, width, height)

    # 检查 ComfyUI
    try:
        url_request.urlopen(f"{COMFYUI_URL}/queue", timeout=5)
    except URLError:
        print(f"  ✗ 无法连接 ComfyUI: {COMFYUI_URL}")
        return None

    prompt_id = queue_prompt(workflow)
    if not prompt_id:
        print(f"  ✗ 提交失败")
        return None
    print(f"  已提交, prompt_id={prompt_id[:8]}…")

    history_entry = wait_for_completion(prompt_id)
    if not history_entry:
        return None

    output_images = get_output_filenames(history_entry)
    if not output_images:
        print(f"  ⚠ 没有找到输出文件")
        return None

    # 根据实际类型确定子类型名
    type_map = {}
    for cn, en, desc, w, h in DECO_LIST:
        type_map[en.lower()] = en
    local_path = OUTPUT_DIR / f"deco_substrate_sand_1.png"
    fname, subfolder, img_type = output_images[0]
    download_image(fname, subfolder, img_type, local_path)
    if local_path.exists():
        print(f"  ✓ 已保存: {local_path}")
        # 复制到游戏 assets
        if GAME_ASSETS_DIR:
            game_path = GAME_ASSETS_DIR / f"deco_substrate_sand_1.png"
            game_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(local_path, game_path)
            print(f"  ✓ 已复制到游戏资源: {game_path}")
        return local_path
    else:
        print(f"  ✗ 下载失败")
        return None


def main():
    print("=" * 50)
    print("  ComfyUI 生成装饰图片")
    print("=" * 50)

    if not WORKFLOW_PATH.exists():
        print(f"✗ 找不到工作流: {WORKFLOW_PATH}")
        return

    args = sys.argv[1:]
    if args:
        result = find_deco(" ".join(args))
        if not result:
            print(f"✗ 未找到装饰: {' '.join(args)}")
            return
        selections = [result]
    else:
        result = pick_interactive()
        if not result:
            print("已取消")
            return
        selections = [result]

    for idx, sel in enumerate(selections, 1):
        _, cn, en, desc, w, h = sel
        generate(cn, en, desc, w, h, idx, len(selections))


if __name__ == "__main__":
    main()
