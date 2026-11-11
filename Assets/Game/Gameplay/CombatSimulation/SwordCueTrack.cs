using System.Collections.Generic;

namespace ShanhaiDingGuard.Gameplay.CombatSimulation
{
    /// <summary>
    /// 飞剑收尾状态，不碰 Unity。同一把剑的命中条和消散淡出只开始一次。
    /// 淡出结束后记住 Id，冻结快照里还留着这把剑时也不再重建。
    /// 换关或重开要 <see cref="Clear"/>，因为新对局的剑 Id 会从 1 再数。
    /// </summary>
    public sealed class SwordCueTrack
    {
        public const float FadeSeconds = 0.2f;
        public const float TrailSeconds = 0.25f;

        public struct Decision
        {
            public bool Show;
            public bool BeginHit;
            public bool BeginFade;
        }

        private sealed class Slot
        {
            public bool Ending;
            public float FadeStart = -1f;
        }

        private readonly Dictionary<int, Slot> _slots = new Dictionary<int, Slot>();
        private readonly HashSet<int> _retired = new HashSet<int>();
        private readonly HashSet<int> _seen = new HashSet<int>();
        private readonly List<int> _ids = new List<int>();
        private readonly List<int> _drop = new List<int>();

        public static float RetireAfterSeconds
        {
            get { return FadeSeconds > TrailSeconds ? FadeSeconds : TrailSeconds; }
        }

        public void Clear()
        {
            _slots.Clear();
            _retired.Clear();
            _seen.Clear();
            _ids.Clear();
            _drop.Clear();
        }

        public void BeginFrame()
        {
            _seen.Clear();
        }

        public bool IsRetired(int id)
        {
            return _retired.Contains(id);
        }

        public Decision Observe(int id, bool hitThisTick, bool dissipatedThisTick, float anim)
        {
            var decision = new Decision();
            if (_retired.Contains(id))
            {
                return decision;
            }

            _seen.Add(id);
            Slot slot;
            if (!_slots.TryGetValue(id, out slot))
            {
                slot = new Slot();
                _slots.Add(id, slot);
            }

            if (CombatSimulation.ShouldBeginSwordHit(hitThisTick, slot.Ending))
            {
                slot.Ending = true;
                if (slot.FadeStart < 0f)
                {
                    slot.FadeStart = anim;
                }

                decision.BeginHit = true;
            }
            else if (dissipatedThisTick && slot.FadeStart < 0f)
            {
                slot.Ending = true;
                slot.FadeStart = anim;
                decision.BeginFade = true;
            }

            decision.Show = true;
            return decision;
        }

        /// <summary>
        /// 本帧没再出现、且还没收尾的剑丢掉。收尾时间到了的剑记入已收尾，调用方销毁画面后不要按原 Id 再建。
        /// </summary>
        public List<int> EndFrame(float anim)
        {
            _drop.Clear();
            _ids.Clear();
            foreach (var pair in _slots)
            {
                _ids.Add(pair.Key);
            }

            var hold = RetireAfterSeconds;
            for (var i = 0; i < _ids.Count; i++)
            {
                var id = _ids[i];
                var slot = _slots[id];
                var seen = _seen.Contains(id);
                if (!seen && !slot.Ending)
                {
                    _slots.Remove(id);
                    _drop.Add(id);
                    continue;
                }

                if (slot.FadeStart >= 0f && anim - slot.FadeStart >= hold)
                {
                    _slots.Remove(id);
                    _retired.Add(id);
                    _drop.Add(id);
                }
            }

            return _drop;
        }
    }
}
