using System;
using ShanhaiDingGuard.Content;

namespace ShanhaiDingGuard.Gameplay.Wave
{
    /// <summary>
    /// 按关卡表刷怪。第一波的第一只在开战第一个 tick 出现。
    /// 同组后续敌人，以及下一波的第一只，都等待「下一组」的 intervalTicks。
    /// 表上的 intervalTicks 不是两只之间的 tick 差：cooldown 设成该值之后，
    /// 接下来每个 tick 只减 1 并返回，减到 0 的那一拍仍然不刷，下一拍才生成。
    /// 实际间隔是 intervalTicks + 1。这是现行口径，不要改成「恰好隔 intervalTicks」，
    /// 否则无塔第 3 漏会从 946 回到按字面间隔计算的 943 一带，切片基线要整表重测。
    /// </summary>
    public sealed class WaveDirector
    {
        private readonly LevelDefinition _level;
        private int _waveIndex;
        private int _groupIndex;
        private int _spawnedInGroup;
        private int _cooldown;
        private int _displayWaveIndex;

        public WaveDirector(LevelDefinition level)
        {
            if (level == null)
            {
                throw new ArgumentNullException("level");
            }

            _level = level;
        }

        public bool Finished { get; private set; }

        public int WaveCount
        {
            get { return _level.Waves.Count; }
        }

        /// <summary>已经刷完的波数。当前正在刷的波不算。</summary>
        public int SpawnedWaveCount
        {
            get { return Finished ? _level.Waves.Count : _waveIndex; }
        }

        /// <summary>1 起。开打前为 1。波间停顿仍显示上一波，直到下一波第一只出现。</summary>
        public int CurrentWaveNumber
        {
            get { return _level.Waves.Count == 0 ? 0 : _displayWaveIndex + 1; }
        }

        public void Tick(Action<string, int, double> spawn)
        {
            if (Finished)
            {
                return;
            }

            if (_cooldown > 0)
            {
                // 减到 0 的这一拍直接返回，不刷怪。实际间隔因此是 intervalTicks + 1。不要改。
                _cooldown--;
                return;
            }

            var wave = _level.Waves[_waveIndex];
            var group = wave.Spawns[_groupIndex];
            var waveIndex = _waveIndex;
            _displayWaveIndex = waveIndex;
            spawn(group.EnemyId, waveIndex, group.HpMultiplier);
            _spawnedInGroup++;
            if (_spawnedInGroup < group.Count)
            {
                _cooldown = group.IntervalTicks;
                return;
            }

            _groupIndex++;
            _spawnedInGroup = 0;
            if (_groupIndex < wave.Spawns.Count)
            {
                _cooldown = wave.Spawns[_groupIndex].IntervalTicks;
                return;
            }

            _waveIndex++;
            _groupIndex = 0;
            if (_waveIndex >= _level.Waves.Count)
            {
                Finished = true;
                return;
            }

            _cooldown = _level.Waves[_waveIndex].Spawns[0].IntervalTicks;
        }
    }
}
