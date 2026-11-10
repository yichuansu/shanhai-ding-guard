using System.Collections.Generic;
using UnityEngine;

namespace ShanhaiDingGuard.Presentation
{
    /// <summary>
    /// 冀州 01 的 2× 母版。放在 Resources/BattleArt，导入参数写在各自的 .meta。
    /// 缺任何一张时整套退回色块，避免只换到一半。
    /// </summary>
    public sealed class BattleArt
    {
        public Sprite TowerBody;
        public Sprite[] TowerFx;
        public Sprite[] Walk;
        public Sprite HitWhite;
        public Sprite HitRed;
        public Sprite Death;
        public Sprite Ding;
        public Sprite SlotNormal;
        public Sprite SlotSelected;
        public Sprite SlotDisabled;
        public Sprite Lingshi;
        public Sprite Heart;
        public Sprite Wave;
        public Material Additive;
        public bool Ready;

        public static BattleArt Load()
        {
            var art = new BattleArt();
            art.TowerBody = Resources.Load<Sprite>("BattleArt/tower_jin_body");
            art.TowerFx = LoadFrames("BattleArt/tower_jin_fx", "fx_", 4);
            art.Walk = LoadFrames("BattleArt/enemy_dangkang_walk", "walk_", 8);
            art.HitWhite = Resources.Load<Sprite>("BattleArt/enemy_dangkang_hit_flash_white");
            art.HitRed = Resources.Load<Sprite>("BattleArt/enemy_dangkang_hit_flash_red");
            art.Death = Resources.Load<Sprite>("BattleArt/enemy_dangkang_death");
            art.Ding = Resources.Load<Sprite>("BattleArt/ding_bronze");
            art.SlotNormal = LoadNamed("BattleArt/buildslot_states", "slot_normal");
            art.SlotSelected = LoadNamed("BattleArt/buildslot_states", "slot_selected");
            art.SlotDisabled = LoadNamed("BattleArt/buildslot_states", "slot_disabled");
            art.Lingshi = Resources.Load<Sprite>("BattleArt/hud_lingshi");
            art.Heart = Resources.Load<Sprite>("BattleArt/hud_heart");
            art.Wave = Resources.Load<Sprite>("BattleArt/hud_wave");
            art.Additive = Resources.Load<Material>("BattleArt/SpriteAdditive");
            art.Ready = art.TowerBody != null
                && art.TowerFx != null
                && art.Walk != null
                && art.HitWhite != null
                && art.HitRed != null
                && art.Death != null
                && art.Ding != null
                && art.SlotNormal != null
                && art.SlotSelected != null
                && art.SlotDisabled != null
                && art.Lingshi != null
                && art.Heart != null
                && art.Wave != null;
            if (!art.Ready)
            {
                Debug.LogWarning("冀州 01 战斗图未齐，建造格和单位继续用色块。");
            }

            return art;
        }

        private static Sprite LoadNamed(string resourcePath, string spriteName)
        {
            var loaded = Resources.LoadAll<Sprite>(resourcePath);
            if (loaded == null)
            {
                return null;
            }

            for (var i = 0; i < loaded.Length; i++)
            {
                if (loaded[i] != null && loaded[i].name == spriteName)
                {
                    return loaded[i];
                }
            }

            return null;
        }

        private static Sprite[] LoadFrames(string resourcePath, string prefix, int count)
        {
            var loaded = Resources.LoadAll<Sprite>(resourcePath);
            if (loaded == null || loaded.Length == 0)
            {
                return null;
            }

            var list = new List<Sprite>();
            for (var i = 0; i < loaded.Length; i++)
            {
                if (loaded[i] != null && loaded[i].name.StartsWith(prefix))
                {
                    list.Add(loaded[i]);
                }
            }

            list.Sort((a, b) => string.CompareOrdinal(a.name, b.name));
            if (list.Count != count)
            {
                return null;
            }

            return list.ToArray();
        }
    }
}
