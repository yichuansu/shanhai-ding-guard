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
        public Sprite Sword;
        public Sprite[] SwordShimmer;
        public Sprite SwordAfterimage;
        public Sprite[] SwordHit;
        public Texture2D SwordTrail;
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
            art.Sword = Resources.Load<Sprite>("BattleArt/proj_jin_sword");
            art.SwordShimmer = LoadFrames("BattleArt/proj_jin_sword_shimmer_strip", "shimmer_", 4);
            art.SwordAfterimage = Resources.Load<Sprite>("BattleArt/proj_jin_trail_afterimage");
            art.SwordHit = LoadFrames("BattleArt/proj_jin_hit_strip", "hit_", 3);
            art.SwordTrail = Resources.Load<Texture2D>("BattleArt/proj_jin_trail");
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

            list.Sort(CompareFrameNames);
            if (list.Count != count)
            {
                return null;
            }

            return list.ToArray();
        }

        /// <summary>
        /// 帧名末尾按数字排。字典序会把 fx_10 排到 fx_2 前面。
        /// </summary>
        private static int CompareFrameNames(Sprite a, Sprite b)
        {
            var ai = TrailingNumber(a != null ? a.name : null);
            var bi = TrailingNumber(b != null ? b.name : null);
            if (ai != bi)
            {
                return ai.CompareTo(bi);
            }

            return string.CompareOrdinal(a != null ? a.name : null, b != null ? b.name : null);
        }

        private static int TrailingNumber(string name)
        {
            if (string.IsNullOrEmpty(name))
            {
                return int.MaxValue;
            }

            var end = name.Length;
            var start = end;
            while (start > 0 && name[start - 1] >= '0' && name[start - 1] <= '9')
            {
                start--;
            }

            if (start == end)
            {
                return int.MaxValue;
            }

            var value = 0;
            for (var i = start; i < end; i++)
            {
                value = (value * 10) + (name[i] - '0');
            }

            return value;
        }
    }
}
