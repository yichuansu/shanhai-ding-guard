using System;
using ShanhaiDingGuard.Content;

namespace ShanhaiDingGuard.Gameplay.Wave
{
    /// <summary>
    /// 按关卡表刷怪。第一波的第一只在开战第一个 tick 出现。
    /// 同组后续敌人，以及下一波的第一只，都等待该组的 intervalTicks。
    /// </summary>
    public sealed class WaveDirector
    {
        private readonly LevelDefinition _level;
        private int _waveIndex;
        private int _groupIndex;
        private int _spawnedInGroup;
        private int _cooldown;

        public WaveDirector(LevelDefinition level)
        {
            if (level == null)
            {
                throw new ArgumentNullException("level");
            }

            _level = level;
        }

        public bool Finished { get; private set; }

        public void Tick(Action<string> spawn)
        {
            if (Finished)
            {
                return;
            }

            if (_cooldown > 0)
            {
                _cooldown--;
                return;
            }

            var wave = _level.Waves[_waveIndex];
            var group = wave.Spawns[_groupIndex];
            spawn(group.EnemyId);
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
