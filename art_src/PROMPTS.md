# 异兽绘图提示词

由 `tools/art/make_prompts.gd` 根据内容数据生成，不要手改；要调整外观描述，改脚本里的 LOOKS 再重新生成。
用法见 `docs/ART_PIPELINE.md`。每只异兽：提示词 → 生成 → 挑一张存为 `art_src/beasts/<id>/raw.png` → 运行 `prepare_beast.py`。

通用负面提示词（支持的工具里填到 negative prompt）：

```
text, letters, calligraphy, seal stamp, border, frame, multiple creatures, human, cropped, photorealistic, 3d render, gradient background, glossy, anime, chibi, watermark
```

## 精卫 Jingwei, the Sea-Filling Bird（木）

原文：有鸟焉，其状如乌，文首，白喙，赤足，名曰精卫……常衔西山之木石，以堙于东海。

保存为：`art_src/beasts/jingwei/raw.png`

```
a small crow-like bird with a patterned head, white beak and red feet, carrying a twig in its beak, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: muted pine green (#2f7d5a) with deep green and pale green accents and black ink
```

## 毕方 Bifang, the One-Legged Fire Crane（火）

原文：有鸟焉，其状如鹤，一足，赤文青质而白喙，名曰毕方，见则其邑有讹火。

保存为：`art_src/beasts/bifang/raw.png`

```
a crane-like bird standing on a single leg, red patterns on a dark blue-green body, white beak, sparks of fire around it, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: cinnabar red (#b9402c) with dark red and salmon accents and black ink
```

## 当康 Dangkang, the Harvest Boar（土）

原文：有兽焉，其状如豚而有牙，其名曰当康，其鸣自叫，见则天下大穰。

保存为：`art_src/beasts/dangkang/raw.png`

```
a wild boar-like beast with long curved tusks, stocky body, bristly back, calling out its own name, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: ochre yellow (#b8892e) with dark ochre and pale sand accents and black ink
```

## 狸力 Lili, the Spurred Digger（土）

原文：有兽焉，其状如豚，有距，其音如狗吠，其名曰狸力，见则其县多土功。

保存为：`art_src/beasts/lili/raw.png`

```
a pig-like beast with sharp spurs on its legs like a rooster, digging the earth, barking like a dog, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: ochre yellow (#b8892e) with dark ochre and pale sand accents and black ink
```

## 鸣蛇 Mingshe, the Four-Winged Drought Snake（金）

原文：其中多鸣蛇，其状如蛇而四翼，其音如磬，见则其邑大旱。

保存为：`art_src/beasts/mingshe/raw.png`

```
a snake with four feathered wings, coiled body, mouth open as if ringing like a stone chime, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: pale silver white (#c9d0d4) with grey accents and black ink
```

## 朱厌 Zhuyan, the War-Omen Ape（金）

原文：有兽焉，其状如猿，而白首赤足，名曰朱厌，见则大兵。

保存为：`art_src/beasts/zhuyan/raw.png`

```
an ape-like beast with a white head and red feet, aggressive war stance, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: pale silver white (#c9d0d4) with grey accents and black ink
```

## 夫诸 Fuzhu, the Four-Horned White Deer（水）

原文：有兽焉，其状如白鹿而四角，名曰夫诸，见则其邑大水。

保存为：`art_src/beasts/fuzhu/raw.png`

```
a white deer with four antlers, slender legs, calm watchful pose, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 化蛇 Huashe, the Flood Serpent（水）

原文：其中多化蛇，其状如人面而豺身，鸟翼而蛇行，其音如叱呼，见则其邑大水。

保存为：`art_src/beasts/huashe/raw.png`

```
a creature with a human face and a jackal body, bird wings on its back, moving like a snake, water splashing, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 文鳐鱼 Wenyao, the Winged Carp（水）

原文：是多文鳐鱼，状如鲤鱼，鱼身而鸟翼，苍文而白首赤喙，见则天下大穰。

保存为：`art_src/beasts/wenyao/raw.png`

```
a carp-like fish with bird wings, dark patterns, white head and red beak, leaping through the air, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 絜钩 Jiegou, the Rat-Tailed Plague Duck（木）

原文：硜山……有鸟焉，其状如凫而鼠尾，善登木，其名曰絜钩，见则其国多疫。

保存为：`art_src/beasts/jiegou/raw.png`

```
a wild-duck-like bird with a long rat tail, climbing a tree branch, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: muted pine green (#2f7d5a) with deep green and pale green accents and black ink
```

## 蠪蛭 Longzhi, the Nine-Headed Fox（木）

原文：凫丽之山……有兽焉，其状如狐，而九尾、九首、虎爪，名曰蠪蛭，其音如婴儿，是食人。

保存为：`art_src/beasts/longzhi/raw.png`

```
a fox-like beast with nine tails, nine heads and tiger claws, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: muted pine green (#2f7d5a) with deep green and pale green accents and black ink
```

## 獙獙 Bibi, the Winged Drought Fox（火）

原文：姑逢之山……有兽焉，其状如狐而有翼，其音如鸿雁，其名曰獙獙，见则天下大旱。

保存为：`art_src/beasts/bibi/raw.png`

```
a fox-like beast with bird wings, honking like a wild goose, dry cracked ground beneath, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: cinnabar red (#b9402c) with dark red and salmon accents and black ink
```

## 朱獳 Zhuru, the Fish-Finned Fox（火）

原文：耿山……有兽焉，其状如狐而鱼翼，其名曰朱獳，其鸣自叫，见则其国有恐。

保存为：`art_src/beasts/zhuru/raw.png`

```
a fox-like beast with fish fins instead of wings, crouching nervously, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: cinnabar red (#b9402c) with dark red and salmon accents and black ink
```

## 鵹鹕 Lihu, the Human-Footed Mandarin Duck（土）

原文：卢其之山……其中多鵹鹕，其状如鸳鸯而人足，其鸣自訆，见则其国多土功。

保存为：`art_src/beasts/lihu/raw.png`

```
a mandarin-duck-like bird with human feet, waddling, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: ochre yellow (#b8892e) with dark ochre and pale sand accents and black ink
```

## 峳峳 Youyou, the Four-Horned Cunning Horse（金）

原文：碧山……有兽焉，其状如马而羊目，四角，牛尾，其音如獆狗，其名曰峳峳，见则其国多狡客。

保存为：`art_src/beasts/youyou/raw.png`

```
a horse-like beast with goat eyes, four horns and an ox tail, howling, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: pale silver white (#c9d0d4) with grey accents and black ink
```

## 合窳 Heyu, the Man-Faced Boar（水）

原文：剡山……有兽焉，其状如彘而人面，黄身而赤尾，其名曰合窳，其音如婴儿。是兽也，食人，亦食虫蛇，见则天下大水。

保存为：`art_src/beasts/heyu/raw.png`

```
a boar-like beast with a human face, yellow body and red tail, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 軨軨 Lingling, the Tiger-Striped Ox（水）

原文：空桑之山……有兽焉，其状如牛而虎文，其音如钦，其名曰軨軨，其鸣自叫，见则天下大水。

保存为：`art_src/beasts/lingling/raw.png`

```
an ox-like beast with tiger stripes, lowing, sturdy stance, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 句芒 Goumang, God of the East and Wood（木）

原文：东方句芒，鸟身人面，乘两龙。

保存为：`art_src/beasts/goumang/raw.png`

```
a deity with a bird body and a human face, riding two small dragons, spring leaves around, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: muted pine green (#2f7d5a) with deep green and pale green accents and black ink
```

## 凤皇 Fenghuang, the Five-Hued Phoenix（火）

原文：丹穴之山……有鸟焉，其状如鸡，五采而文，名曰凤皇……是鸟也，饮食自然，自歌自舞，见则天下安宁。

保存为：`art_src/beasts/fenghuang/raw.png`

```
a phoenix shaped like a rooster with five-colored patterned plumage, long flowing tail feathers, dancing, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: cinnabar red (#b9402c) with dark red and salmon accents and black ink
```

## 夔 Kui, the One-Legged Thunder Ox（土）

原文：东海中有流波山……其上有兽，状如牛，苍身而无角，一足……其声如雷，其名曰夔。黄帝得之，以其皮为鼓……声闻五百里，以威天下。

保存为：`art_src/beasts/kui/raw.png`

```
a one-legged ox with a dark grey-green hornless body, glowing like the sun and moon, thunder around it, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: ochre yellow (#b8892e) with dark ochre and pale sand accents and black ink
```

## 驳 Bo, the Tiger-Eating Horse（金）

原文：有兽焉，其状如马而白身黑尾，一角，虎牙爪，音如鼓音，其名曰驳，是食虎豹，可以御兵。

保存为：`art_src/beasts/bo/raw.png`

```
a white horse with a black tail and a single horn, tiger fangs and claws, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: pale silver white (#c9d0d4) with grey accents and black ink
```

## 天吴 Tianwu, the Eight-Headed Water Lord（水）

原文：朝阳之谷，神曰天吴，是为水伯……其为兽也，八首人面，八足八尾，皆青黄。

保存为：`art_src/beasts/tianwu/raw.png`

```
a water deity with eight human heads, a tiger body, eight legs and eight tails, blue-yellow coloring, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 应龙 Yinglong, the Winged Rain Dragon（水）

原文：应龙处南极，杀蚩尤与夸父，不得复上，故下数旱，旱而为应龙之状，乃得大雨。

保存为：`art_src/beasts/yinglong/raw.png`

```
a winged dragon with large feathered wings, summoning rain clouds, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 蜚 Fei, the One-Eyed Plague Ox（金）

原文：太山……有兽焉，其状如牛而白首，一目而蛇尾，其名曰蜚，行水则竭，行草则死，见则天下大疫。

保存为：`art_src/beasts/fei/raw.png`

```
an ox-like beast with a white head, a single eye and a snake tail, withered grass around its hooves, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: pale silver white (#c9d0d4) with grey accents and black ink
```

## 相柳 Xiangliu, the Nine-Headed Serpent（水）

原文：共工之臣曰相柳氏，九首，以食于九山……禹杀相柳，其血腥，不可以树五谷种。

保存为：`art_src/beasts/xiangliu/raw.png`

```
a giant serpent with nine human-like heads on long necks, coiled body, menacing, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 鼎煞（火） Cauldron Wraith (Fire)（火）

原文：九鼎崩裂时溢出的浊气。

保存为：`art_src/beasts/dingsha_huo/raw.png`

```
a small swirling wisp of fiery smoke with two hollow eyes, shaped like a crack escaping a bronze cauldron, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: cinnabar red (#b9402c) with dark red and salmon accents and black ink
```

## 鼎煞（金） Cauldron Wraith (Metal)（金）

原文：九鼎崩裂时溢出的浊气。

保存为：`art_src/beasts/dingsha_jin/raw.png`

```
a small swirling wisp of metallic grey smoke with two hollow eyes, shaped like a crack escaping a bronze cauldron, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: pale silver white (#c9d0d4) with grey accents and black ink
```

## 鼎煞（木） Cauldron Wraith (Wood)（木）

原文：九鼎崩裂时溢出的浊气。

保存为：`art_src/beasts/dingsha_mu/raw.png`

```
a small swirling wisp of leafy green smoke with two hollow eyes, shaped like a crack escaping a bronze cauldron, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: muted pine green (#2f7d5a) with deep green and pale green accents and black ink
```

## 鼎煞（水） Cauldron Wraith (Water)（水）

原文：九鼎崩裂时溢出的浊气。

保存为：`art_src/beasts/dingsha_shui/raw.png`

```
a small swirling wisp of watery mist with two hollow eyes, shaped like a crack escaping a bronze cauldron, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: indigo black-blue (#26384d) with slate blue accents and black ink
```

## 鼎煞（土） Cauldron Wraith (Earth)（土）

原文：九鼎崩裂时溢出的浊气。

保存为：`art_src/beasts/dingsha_tu/raw.png`

```
a small swirling wisp of earthy smoke with two hollow eyes, shaped like a crack escaping a bronze cauldron, Chinese woodblock print illustration in the style of a Ming dynasty Shan Hai Jing (Classic of Mountains and Seas) edition, hand-carved bold black ink outlines with varying line weight, flat limited colors, minimal shading done with ink hatching only, single creature, full body, side view facing right, standing on the ground, centered, clear readable silhouette, plain aged rice paper background, generous empty space around the creature, colors: ochre yellow (#b8892e) with dark ochre and pale sand accents and black ink
```
