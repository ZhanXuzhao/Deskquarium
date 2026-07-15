"""
重新生成指定鱼的图片
======================
用法：
  python regenerate_fish.py                   # 交互式选择
  python regenerate_fish.py 清道夫             # 按中文名
  python regenerate_fish.py Plecostomus        # 按英文名
  python regenerate_fish.py 11                 # 按序号（从 1 开始）

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

# ===================== 配置区域 =====================

COMFYUI_URL = "http://127.0.0.1:8188"
WORKFLOW_PATH = Path(__file__).parent / "Text2Image.json"
OUTPUT_DIR = Path(__file__).parent / "output"
GAME_ASSETS_DIR = Path(__file__).parent.parent / "assets" / "fish"

# ===================== 鱼类列表 =====================
# 格式: (中文名, 英文名, prompt 描述)
FISH_LIST = [
    ("红绿灯鱼",     "NeonTetra",         "Paracheirodon innesi, bright blue and red stripe, tiny 3cm"),
    ("宝莲灯鱼",     "CardinalTetra",     "Paracheirodon axelrodi, red belly, bright blue line, 4cm"),
    ("斑马鱼",       "Zebrafish",         "Danio rerio, striped body, small slender fish, 4-6cm"),
    ("孔雀鱼",       "Guppy",             "Poecilia reticulata, colorful tail, small tropical fish"),
    ("玛丽鱼",       "Molly",             "Poecilia latipinna, round body, various colors, 7-10cm"),
    ("米奇鱼",       "MickeyMousePlaty",  "Poecilia hybrid, Mickey Mouse pattern on tail fin"),
    ("红鼻剪刀",     "RummynoseTetra",    "Rasbora heteromorpha, red nose, silver body, 5-6cm"),
    ("三角灯鱼",     "HarlequinRasbora",  "Trigonostigma heteromorpha, triangular black patch, 4-5cm"),
    ("虎皮鱼",       "TigerBarb",         "Puntigrus tetrazona, striped tiger-like pattern, 6-7cm"),
    ("曼龙鱼",       "Gourami",           "Trichopodus trichopterus, large fins, labyrinth fish, 10-14cm"),
    ("珍珠马甲",     "PearlGourami",      "Trichopodus leerii, pearl-like spots on body, 10-12cm"),
    ("清道夫",       "Plecostomus",       "Hypostomus plecostomus, sucker mouth, bottom dweller, 30cm"),
    ("小精灵鱼",     "Otocinclus",        "Otocinclus affinis, tiny algae eater, 4-5cm"),
    ("黄金大胡子",   "BristlenosePleco",  "Ancistrus sp., bristle nose, golden color, 12-15cm"),
    ("神仙鱼",       "Angelfish",         "Pterophyllum scalare, triangular body, long fins, 12-15cm"),
    ("七彩神仙鱼",   "Discus",            "Symphysodon aequifasciatus, disc-shaped, colorful, 15-20cm"),
    ("鼠鱼",         "Corydoras",         "Corydoras paleatus, bottom feeder, armored catfish, 5-6cm"),
    ("斗鱼",         "Betta",             "Betta splendens, large flowing fins, vibrant colors, 5-7cm"),
    ("月光鱼",       "Moonfish",          "Xiphophorus maculatus, small peaceful livebearer, 4-5cm"),
    ("红十字鱼",     "SerpaeTetra",       "Hyphessobrycon eques, red body, black spot, 5-7cm"),
    ("金鱼",         "Goldfish",          "Carassius auratus, round chubby body, fancy tail"),
    ("龙鱼",         "Arowana",           "Scleropages formosus, long sleek body, large scales"),
]


# ===================== 鱼类查找 =====================

def find_fish(query: str) -> Optional[tuple[int, str, str, str]]:
    """
    根据用户输入查找鱼。
    支持：
      - 中文名（如 "清道夫"）
      - 英文名（如 "Plecostomus"，不区分大小写）
      - 序号（如 "11"，从 1 开始）
    返回 (index, cn, en, desc) 或 None。
    """
    # 序号匹配
    if query.isdigit():
        idx = int(query) - 1
        if 0 <= idx < len(FISH_LIST):
            cn, en, desc = FISH_LIST[idx]
            return (idx, cn, en, desc)

    # 中文名匹配（精确）
    for idx, (cn, en, desc) in enumerate(FISH_LIST):
        if query == cn:
            return (idx, cn, en, desc)

    # 英文名匹配（不区分大小写）
    for idx, (cn, en, desc) in enumerate(FISH_LIST):
        if query.lower() == en.lower():
            return (idx, cn, en, desc)

    # 模糊匹配中文名（包含）
    matches = []
    for idx, (cn, en, desc) in enumerate(FISH_LIST):
        if query in cn:
            matches.append((idx, cn, en, desc))
    if len(matches) == 1:
        return matches[0]
    elif len(matches) > 1:
        print(f"  找到多条匹配: {', '.join(m[1] for m in matches)}")
        print(f"  请输入更精确的名称")
        return None

    # 模糊匹配英文名（包含，不区分大小写）
    query_lower = query.lower()
    matches = []
    for idx, (cn, en, desc) in enumerate(FISH_LIST):
        if query_lower in en.lower():
            matches.append((idx, cn, en, desc))
    if len(matches) == 1:
        return matches[0]
    elif len(matches) > 1:
        print(f"  找到多条匹配: {', '.join(f'{m[1]}({m[2]})' for m in matches)}")
        print(f"  请输入更精确的名称")
        return None

    return None


def print_fish_menu():
    """打印鱼类选择菜单"""
    print(f"\n{'='*55}")
    print(f"  可选择的鱼类 ({len(FISH_LIST)} 种)")
    print(f"{'='*55}")
    for i, (cn, en, _) in enumerate(FISH_LIST, 1):
        print(f"  {i:2d}. {cn} ({en})")
    print(f"{'='*55}")


def pick_fish_interactive() -> Optional[tuple[int, str, str, str]]:
    """交互式选择鱼类"""
    print_fish_menu()
    while True:
        try:
            choice = input("\n请输入序号或鱼名 (直接回车取消): ").strip()
            if not choice:
                return None
            result = find_fish(choice)
            if result:
                return result
            print("  ✗ 未找到匹配的鱼，请重新输入")
        except (EOFError, KeyboardInterrupt):
            return None


# ===================== ComfyUI API =====================

def load_workflow_template(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def update_workflow_prompt(workflow: dict, fish_cn: str, fish_en: str, fish_desc: str) -> dict:
    workflow = json.loads(json.dumps(workflow))  # 深拷贝
    prompt_text = (
        f"pixel art fish sprite, side view facing right, horizontal, "
        f"#00ff00 green background, "
        f"{fish_cn} ({fish_en}), {fish_desc}, "
        f"game sprite, centered, flat lighting"
    )
    workflow["72:67"]["inputs"]["text"] = prompt_text
    prefix = f"fish_{fish_en}"
    if "75" in workflow:
        workflow["75"]["inputs"]["filename_prefix"] = prefix
    if "269" in workflow:
        workflow["269"]["inputs"]["filename_prefix"] = prefix
    seed = random.randint(0, 2**63 - 1)
    workflow["72:70"]["inputs"]["seed"] = seed
    return workflow


def queue_prompt(workflow: dict) -> Optional[str]:
    payload = json.dumps({"prompt": workflow}).encode("utf-8")
    req = url_request.Request(
        f"{COMFYUI_URL}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        resp = url_request.urlopen(req, timeout=30)
        result = json.loads(resp.read())
        return result.get("prompt_id")
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
    print(f"  ⚠ 任务超时")
    return {}


def get_output_filenames(history_entry: dict) -> list[tuple[str, str, str]]:
    results = []
    for node_id, node_out in history_entry.get("outputs", {}).items():
        for img_data in node_out.get("images", []):
            img_type = img_data.get("type", "output")
            if img_type == "temp":
                continue
            results.append((
                img_data.get("filename", ""),
                img_data.get("subfolder", ""),
                img_type,
            ))
    return results


def download_image(filename: str, subfolder: str, img_type: str, save_path: Path) -> bool:
    import urllib.parse
    query = urllib.parse.urlencode({
        "filename": filename,
        "subfolder": subfolder,
        "type": img_type,
    })
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


# ===================== 主逻辑 =====================

def generate_one_fish(fish_cn: str, fish_en: str, fish_desc: str) -> bool:
    """生成单条鱼图片，返回是否成功"""
    print(f"\n  正在生成: {fish_cn} ({fish_en})")

    workflow_template = load_workflow_template(WORKFLOW_PATH)
    workflow = update_workflow_prompt(workflow_template, fish_cn, fish_en, fish_desc)

    prompt_id = queue_prompt(workflow)
    if not prompt_id:
        print("  ✗ 提交失败")
        return False
    print(f"  已提交 (prompt_id={prompt_id[:8]}…)")

    history_entry = wait_for_completion(prompt_id)
    if not history_entry:
        print("  ✗ 生成失败")
        return False

    output_images = get_output_filenames(history_entry)
    if not output_images:
        print("  ⚠ 没有找到输出文件")
        return False

    # 保存到输出目录
    local_path = OUTPUT_DIR / f"fish_{fish_en}.png"
    fname, subfolder, img_type = output_images[0]
    download_image(fname, subfolder, img_type, local_path)

    if not local_path.exists():
        print("  ✗ 下载失败")
        return False

    print(f"  ✓ 已保存: {local_path}")

    # 复制到游戏资源目录
    if GAME_ASSETS_DIR:
        game_path = GAME_ASSETS_DIR / f"fish_{fish_en.lower()}.png"
        game_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(local_path, game_path)
        size = os.path.getsize(game_path)
        print(f"  ✓ 已复制到: {game_path} ({size} bytes)")

    return True


def main():
    print("=" * 50)
    print(f"  重新生成鱼图片")
    print("=" * 50)

    # 检查工作流文件
    if not WORKFLOW_PATH.exists():
        print(f"✗ 找不到工作流文件: {WORKFLOW_PATH}")
        return

    # 检查 ComfyUI 连接
    try:
        url_request.urlopen(f"{COMFYUI_URL}/queue", timeout=5)
    except URLError:
        print(f"✗ 无法连接 ComfyUI: {COMFYUI_URL}")
        return

    # 解析命令行参数
    if len(sys.argv) > 1:
        result = find_fish(sys.argv[1])
        if not result:
            print(f"✗ 未找到匹配的鱼: {sys.argv[1]}")
            print_fish_menu()
            return
        idx, cn, en, desc = result
        print(f"\n  目标: {cn} ({en})")
        generate_one_fish(cn, en, desc)
    else:
        # 交互模式
        result = pick_fish_interactive()
        if not result:
            print("  已取消")
            return
        idx, cn, en, desc = result
        confirm = input(f"  确认生成 {cn} ({en})? (Y/n): ").strip().lower()
        if confirm == "n":
            print("  已取消")
            return
        generate_one_fish(cn, en, desc)


if __name__ == "__main__":
    main()
