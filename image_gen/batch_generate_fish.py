"""
ComfyUI 批量生成鱼图片脚本
=============================
使用方法：
1. 确保 ComfyUI 正在运行（默认 http://127.0.0.1:8188）
2. 修改下方配置（COMFYUI_URL、WORKFLOW_PATH、OUTPUT_DIR）
3. 运行: python batch_generate_fish.py

工作流说明：
- 用 Text2Image.json 的工作流模板，替换其中的鱼类 prompt
- 每次生成以 "fish_{英文名}" 为前缀保存
- 支持指定批次大小（batch_size）
"""

import json
import os
import random
import time
import uuid
from pathlib import Path
from typing import Optional
from urllib import request as url_request
from urllib.error import URLError

# ===================== 配置区域 =====================

# ComfyUI 地址
COMFYUI_URL = "http://127.0.0.1:8188"

# 工作流 JSON 路径（当前目录下的 Text2Image.json）
WORKFLOW_PATH = Path(__file__).parent / "Text2Image.json"

# 输出目录（成品 PNG 存放位置）
OUTPUT_DIR = Path(__file__).parent / "output"

# 是否保存到游戏 assets 目录（设为 None 则不保存）
GAME_ASSETS_DIR = Path(__file__).parent.parent / "assets" / "fish"

# 图片尺寸
IMAGE_WIDTH = 256
IMAGE_HEIGHT = 256

# 采样步数
STEPS = 8

# ===================== 鱼类列表 =====================

# 可以从 fish_data.gd 或 doc/fish.md 中提取
# 格式：(中文名, 英文名, 学名/补充描述)
# 鱼列表：doc/fish.md 20 种 + 游戏中已有的金鱼、龙鱼
# 格式：(中文名, 英文名, 学名/补充描述)
FISH_LIST = [
    # --- doc/fish.md ---
    ("红绿灯鱼", "NeonTetra", "Paracheirodon innesi, bright blue and red stripe, tiny 3cm"),
    ("宝莲灯鱼", "CardinalTetra", "Paracheirodon axelrodi, red belly, bright blue line, 4cm"),
    ("斑马鱼", "Zebrafish", "Danio rerio, striped body, small slender fish, 4-6cm"),
    ("孔雀鱼", "Guppy", "Poecilia reticulata, colorful tail, small tropical fish"),
    ("玛丽鱼", "Molly", "Poecilia latipinna, round body, various colors, 7-10cm"),
    ("米奇鱼", "MickeyMousePlaty", "Poecilia hybrid, Mickey Mouse pattern on tail fin"),
    ("红鼻剪刀", "RummynoseTetra", "Rasbora heteromorpha, red nose, silver body, 5-6cm"),
    ("三角灯鱼", "HarlequinRasbora", "Trigonostigma heteromorpha, triangular black patch, 4-5cm"),
    ("虎皮鱼", "TigerBarb", "Puntigrus tetrazona, striped tiger-like pattern, 6-7cm"),
    ("曼龙鱼", "Gourami", "Trichopodus trichopterus, large fins, labyrinth fish, 10-14cm"),
    ("珍珠马甲", "PearlGourami", "Trichopodus leerii, pearl-like spots on body, 10-12cm"),
    ("清道夫", "Plecostomus", "Hypostomus plecostomus, sucker mouth, bottom dweller, 30cm"),
    ("小精灵鱼", "Otocinclus", "Otocinclus affinis, tiny algae eater, 4-5cm"),
    ("黄金大胡子", "BristlenosePleco", "Ancistrus sp., bristle nose, golden color, 12-15cm"),
    ("神仙鱼", "Angelfish", "Pterophyllum scalare, triangular body, long fins, 12-15cm"),
    ("七彩神仙鱼", "Discus", "Symphysodon aequifasciatus, disc-shaped, colorful, 15-20cm"),
    ("鼠鱼", "Corydoras", "Corydoras paleatus, bottom feeder, armored catfish, 5-6cm"),
    ("斗鱼", "Betta", "Betta splendens, large flowing fins, vibrant colors, 5-7cm"),
    ("月光鱼", "Moonfish", "Xiphophorus maculatus, small peaceful livebearer, 4-5cm"),
    ("红十字鱼", "SerpaeTetra", "Hyphessobrycon eques, red body, black spot, 5-7cm"),
    # --- 游戏中已有（不在 fish.md 中）---
    ("金鱼", "Goldfish", "Carassius auratus, round chubby body, fancy tail"),
    ("龙鱼", "Arowana", "Scleropages formosus, long sleek body, large scales"),
]


# ===================== ComfyUI API 交互 =====================

def get_comfyui_queue() -> dict:
    """查询 ComfyUI 队列状态"""
    try:
        resp = url_request.urlopen(f"{COMFYUI_URL}/queue", timeout=5)
        return json.loads(resp.read())
    except Exception as e:
        print(f"  ⚠ 无法查询队列: {e}")
        return {}


def wait_for_queue_space(max_wait: int = 300):
    """等待队列有空位（最多 max_wait 秒）"""
    waited = 0
    while waited < max_wait:
        queue_info = get_comfyui_queue()
        running = len(queue_info.get("queue_running", []))
        pending = len(queue_info.get("queue_pending", []))
        total = running + pending
        if total < 3:  # 队列少于 3 个任务即可提交
            return True
        print(f"  队列中有 {total} 个任务 (running={running}, pending={pending})，等待 10 秒…")
        time.sleep(10)
        waited += 10
    print("  ⚠ 等待超时，强制提交…")
    return True


def queue_prompt(workflow: dict) -> Optional[str]:
    """向 ComfyUI 提交工作流，返回 prompt_id"""
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
    """查询 ComfyUI 任务历史"""
    try:
        resp = url_request.urlopen(
            f"{COMFYUI_URL}/history/{prompt_id}", timeout=10
        )
        return json.loads(resp.read())
    except Exception:
        return {}


def wait_for_completion(prompt_id: str, timeout: int = 120) -> dict:
    """轮询等待任务完成"""
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
    """
    从 ComfyUI 返回结果中提取输出的文件名。
    返回: [(filename, subfolder, type), ...]
    只取 type='output' 的 SaveImage 节点结果，跳过 temp 预览图。
    """
    results = []
    for node_id, node_out in history_entry.get("outputs", {}).items():
        for img_data in node_out.get("images", []):
            img_type = img_data.get("type", "output")
            if img_type == "temp":
                continue  # 跳过预览临时图
            results.append((
                img_data.get("filename", ""),
                img_data.get("subfolder", ""),
                img_type,
            ))
    return results


def download_image(filename: str, subfolder: str, img_type: str, save_path: Path) -> bool:
    """从 ComfyUI 下载图片到本地"""
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


# ===================== 工作流处理 =====================

def load_workflow_template(path: Path) -> dict:
    """加载 ComfyUI 工作流 JSON 模板"""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def update_workflow_prompt(
    workflow: dict,
    fish_cn: str,
    fish_en: str,
    fish_desc: str,
) -> dict:
    """
    修改工作流中的 prompt 文本和输出文件名。
    假设 Text2Image.json 中的 CLIPTextEncode 节点 ID 是 "72:67"，
    SaveImage 节点 ID 是 "75" 和 "269"。
    """
    workflow = json.loads(json.dumps(workflow))  # 深拷贝

    # 1. 更新 CLIP 文本编码节点的 prompt
    prompt_text = (
        f"pixel art fish sprite, side view facing right, horizontal, "
        f"#{'00ff00'} green background, "
        f"{fish_cn} ({fish_en}), {fish_desc}, "
        f"game sprite, centered, flat lighting"
    )
    workflow["72:67"]["inputs"]["text"] = prompt_text

    # 2. 更新输出文件前缀（方便识别）
    prefix = f"fish_{fish_en}"
    if "75" in workflow:
        workflow["75"]["inputs"]["filename_prefix"] = prefix
    if "269" in workflow:
        workflow["269"]["inputs"]["filename_prefix"] = prefix

    # 3. 每次生成使用随机种子（确保多样性）
    seed = random.randint(0, 2**63 - 1)
    workflow["72:70"]["inputs"]["seed"] = seed

    return workflow


# ===================== 主流程 =====================

def generate_single_fish(
    workflow_template: dict,
    fish_cn: str,
    fish_en: str,
    fish_desc: str,
    index: int,
    total: int,
) -> Optional[Path]:
    """生成单种鱼的图片"""
    print(f"\n[{index}/{total}] {fish_cn} ({fish_en})")

    # 准备工作流
    workflow = update_workflow_prompt(workflow_template, fish_cn, fish_en, fish_desc)

    # 等待队列空位
    wait_for_queue_space()

    # 提交任务
    prompt_id = queue_prompt(workflow)
    if not prompt_id:
        print(f"  ✗ 提交失败，跳过")
        return None
    print(f"  已提交，prompt_id={prompt_id[:8]}…")

    # 等待完成
    history_entry = wait_for_completion(prompt_id)
    if not history_entry:
        return None

    # 获取输出的文件名（只取 type=output 的）
    output_images = get_output_filenames(history_entry)
    if not output_images:
        print(f"  ⚠ 没有找到输出文件")
        return None

    # 下载第一张 output 图片
    local_path = OUTPUT_DIR / f"fish_{fish_en}.png"
    fname, subfolder, img_type = output_images[0]
    download_image(fname, subfolder, img_type, local_path)

    if local_path.exists():
        print(f"  ✓ 已保存: {local_path}")

        # 同时复制到游戏 assets 目录
        if GAME_ASSETS_DIR:
            game_path = GAME_ASSETS_DIR / f"fish_{fish_en.lower()}.png"
            game_path.parent.mkdir(parents=True, exist_ok=True)
            import shutil
            shutil.copy2(local_path, game_path)
            print(f"  ✓ 已复制到游戏资源: {game_path}")
        return local_path
    else:
        print(f"  ✗ 下载失败")
        return None


def main():
    print("=" * 50)
    print("  ComfyUI 批量生成鱼图片")
    print("=" * 50)

    # 检查工作流文件
    if not WORKFLOW_PATH.exists():
        print(f"✗ 找不到工作流文件: {WORKFLOW_PATH}")
        return

    # 检查 ComfyUI 连接
    print(f"\n[*] 检查 ComfyUI 连接 ({COMFYUI_URL})…")
    try:
        url_request.urlopen(f"{COMFYUI_URL}/queue", timeout=5)
        print("  ✓ ComfyUI 连接成功")
    except URLError:
        print(f"  ✗ 无法连接 ComfyUI，请确保已启动: {COMFYUI_URL}")
        return

    # 加载工作流模板
    workflow_template = load_workflow_template(WORKFLOW_PATH)
    print(f"  ✓ 工作流已加载: {WORKFLOW_PATH.name}")

    # 创建输出目录
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # ====== 选择模式 ======
    print(f"\n鱼类总数: {len(FISH_LIST)}")
    print(f"  0: 全部生成")
    for i, (cn, en, _) in enumerate(FISH_LIST, 1):
        print(f"  {i}: {cn} ({en})")

    # 默认全部生成
    selected = list(range(len(FISH_LIST)))
    total = len(selected)

    print(f"\n[*] 开始批量生成 (共 {total} 种鱼)")
    success = 0
    for idx, fish_idx in enumerate(selected, 1):
        fish_cn, fish_en, fish_desc = FISH_LIST[fish_idx]
        result = generate_single_fish(
            workflow_template, fish_cn, fish_en, fish_desc,
            idx, total,
        )
        if result:
            success += 1

    # 汇总
    print(f"\n{'=' * 50}")
    print(f"  生成完成: {success}/{total} 种鱼成功")
    print(f"  输出目录: {OUTPUT_DIR}")
    if GAME_ASSETS_DIR:
        print(f"  游戏资源: {GAME_ASSETS_DIR}")
    print(f"{'=' * 50}")


if __name__ == "__main__":
    main()
