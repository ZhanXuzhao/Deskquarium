# 装饰物列表

> 项目中共有 **18 种** 装饰物，代码定义在 `data/decoration_data.gd` 的 `DecorationType` 枚举中。

| # | 中文名 | 英文名（代码） | 类型 | 纹理文件 | 尺寸 | 购买价 | 出售价 | 游戏内描述 | 生图描述（AI Prompt） |
| :-: | :--- | :--- | :--- | :--- | :-: | :-: | :-: | :--- | :--- |
| 1 | 水榕 | Anubias | 水草 (Plant) | `deco_plant_anubias.png` | 256×256 | 80 | 40 | 漂亮的水榕，适合绑在沉木上。 | pixel art aquatic plant, Anubias, broad dark green leaves on rhizome, #00ff00 green background, game asset, centered |
| 2 | 椒草 | Bucephalandra | 水草 (Plant) | `deco_plant_bucephalandra.png` | 256×256 | 100 | 50 | 精致的椒草，增添绿色层次。 | pixel art aquatic plant, Bucephalandra, small round leaves in layered rosette, #00ff00 green background, game asset, centered |
| 3 | 海螺 | Conch | 装饰 (Decoration) | `deco_ornament_conch.png` | 256×256 | 60 | 30 | 来自海洋的海螺壳。 | pixel art seashell, conch spiral shell, light brown and white stripes, #00ff00 green background, game asset, centered |
| 4 | 珊瑚（红） | Coral1 | 珊瑚 (Coral) | `deco_coral_coral_1.png` | 256×256 | 120 | 60 | 红色的珊瑚装饰。 | pixel art coral, bright red branching coral, #00ff00 green background, game asset, centered |
| 5 | 珊瑚（蓝） | Coral2 | 珊瑚 (Coral) | `deco_coral_coral_2.png` | 256×256 | 120 | 60 | 蓝色的珊瑚装饰。 | pixel art coral, bright blue branching coral, #00ff00 green background, game asset, centered |
| 6 | 珊瑚（紫） | Coral3 | 珊瑚 (Coral) | `deco_coral_coral_3.png` | 256×256 | 120 | 60 | 紫色的珊瑚装饰。 | pixel art coral, purple branching coral, #00ff00 green background, game asset, centered |
| 7 | 珊瑚骨（大） | CoralBone1 | 珊瑚 (Coral) | `deco_coral_coral_bone_1.png` | 256×256 | 100 | 50 | 大块的珊瑚骨，营造自然景观。 | pixel art coral skeleton, large white coral bone fragment, porous texture, #00ff00 green background, game asset, centered |
| 8 | 珊瑚骨（小） | CoralBone2 | 珊瑚 (Coral) | `deco_coral_coral_bone_2.png` | 256×256 | 80 | 40 | 小块的珊瑚骨，适合点缀。 | pixel art coral skeleton, small white coral bone piece, #00ff00 green background, game asset, centered |
| 9 | 水蕴草 | Hydrilla | 水草 (Plant) | `deco_plant_hydrilla.png` | 256×256 | 60 | 30 | 茂盛的水蕴草，快速生长。 | pixel art aquatic plant, Hydrilla, long thin green stems with tiny leaves, #00ff00 green background, game asset, centered |
| 10 | 莫斯 1 | Moss1 | 水草 (Plant) | `deco_plant_moss_1.png` | 256×256 | 50 | 25 | 莫斯草皮 1 号。 | pixel art moss ball, round fluffy green moss cluster, #00ff00 green background, game asset, centered |
| 11 | 莫斯 2 | Moss2 | 水草 (Plant) | `deco_plant_moss_2.png` | 256×256 | 50 | 25 | 莫斯草皮 2 号。 | pixel art moss carpet, flat spreading green moss patch, #00ff00 green background, game asset, centered |
| 12 | 莫斯 3 | Moss3 | 水草 (Plant) | `deco_plant_moss_3.png` | 256×256 | 50 | 25 | 莫斯草皮 3 号。 | pixel art moss on driftwood, green moss clump attached to wood, #00ff00 green background, game asset, centered |
| 13 | 莫斯 4 | Moss4 | 水草 (Plant) | `deco_plant_moss_4.png` | 256×256 | 50 | 25 | 莫斯草皮 4 号。 | pixel art moss wall, vertical green moss coverage, #00ff00 green background, game asset, centered |
| 14 | 细沙（浅） | Sand1 | 底砂 (Substrate) | `deco_substrate_sand_1.png` | 256×256 | 40 | 20 | 浅色细沙，铺设缸底。 | pixel art substrate, light beige fine sand texture, #00ff00 green background, game asset, centered |
| 15 | 细沙（深） | Sand2 | 底砂 (Substrate) | `deco_substrate_sand_2.png` | 256×256 | 40 | 20 | 深色细沙，铺设缸底。 | pixel art substrate, dark brown fine sand texture, #00ff00 green background, game asset, centered |
| 16 | 贝壳 | Seashell | 装饰 (Decoration) | `deco_ornament_seashell.png` | 256×256 | 70 | 35 | 精美的贝壳。 | pixel art seashell, scallop shell with ridges, light pink and white, #00ff00 green background, game asset, centered |
| 17 | 虾屋 | ShrimpAve | 装饰 (Decoration) | `deco_ornament_shrimp_ave.png` | 256×256 | 90 | 45 | 虾屋，为虾类提供住所。 | pixel art shrimp hideout, small clay cave with round entrance, #00ff00 green background, game asset, centered |
| 18 | 水兰 | Vallisneria | 水草 (Plant) | `deco_plant_vallisneria.png` | 256×256 | 70 | 35 | 水兰，飘逸的长叶水草。 | pixel art aquatic plant, Vallisneria, long ribbon-like green leaves flowing upward, #00ff00 green background, game asset, centered |

> **备注：** 生图描述按照与鱼类一致的 `pixel art ... #00ff00 green background, game asset, centered` 风格编写，方便后续接入 ComfyUI 等工具进行 AI 批量生成。
