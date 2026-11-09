using System.Collections.Generic;
using ShanhaiDingGuard.Content;
using ShanhaiDingGuard.Gameplay.Capture;
using ShanhaiDingGuard.Gameplay.Hero;
using ShanhaiDingGuard.Gameplay.Path;
using ShanhaiDingGuard.Gameplay.Towers;
using ShanhaiDingGuard.Gameplay.Wave;

namespace ShanhaiDingGuard.Gameplay.CombatSimulation
{
    public enum BattlePhase
    {
        Ready = 0,
        Running = 1,
        Won = 2,
        Lost = 3,
    }

    public sealed class EnemyUnit
    {
        public int InstanceId;
        public string DefId;
        public double Distance;
        public double PreviousDistance;
        public double X;
        public double Y;
        public int Hp;
        public int MaxHp;
        public double Speed;
        public int LeakDamage;
        public bool Alive;
    }

    public sealed class EnemyView
    {
        public int InstanceId;
        public double Distance;
        public double X;
        public double Y;
        public int Hp;
        public int MaxHp;
        public double Speed;
    }

    public sealed class TowerView
    {
        public string Id;
        public string CellId;
        public double X;
        public double Y;
        public double Range;
    }

    public sealed class CellView
    {
        public string Id;
        public double X;
        public double Y;
        public bool Occupied;
        public bool Queued;
    }

    public sealed class BattleSnapshot
    {
        public int Tick;
        public BattlePhase Phase;
        public int LeakCount;
        public int AccumulatedLeakDamage;
        public int LoseLeakCount;
        public string LoseRule;
        public string WinRule;
        public bool WavesFinished;
        public string Note;
        public List<EnemyView> Enemies = new List<EnemyView>();
        public List<TowerView> Towers = new List<TowerView>();
        public List<CellView> Cells = new List<CellView>();
    }

    /// <summary>
    /// 固定 tick 的权威对局。倍速不进这个类：调用方决定一帧调用几次 Tick。
    /// 单次伤害始终是塔表上的 damage，不乘元素表（M1 没有元素表）。
    /// </summary>
    public sealed class CombatSimulation
    {
        private readonly SliceBattleContent _content;
        private readonly WaveDirector _waves;
        private readonly List<EnemyUnit> _enemies = new List<EnemyUnit>();
        private readonly List<TowerState> _towers = new List<TowerState>();
        private readonly Queue<PlaceIntent> _intents = new Queue<PlaceIntent>();
        private readonly IHeroActions _hero = new IdleHero();
        private readonly ICaptureRules _capture = new IdleCapture();
        private int _nextEnemyId = 1;

        private CombatSimulation(SliceBattleContent content)
        {
            _content = content;
            Path = new PathCurve(content.Level.Waypoints);
            _waves = new WaveDirector(content.Level);
            Phase = BattlePhase.Ready;
            Publish();
        }

        public PathCurve Path { get; }

        public BattlePhase Phase { get; private set; }

        public int TickCount { get; private set; }

        public int LeakCount { get; private set; }

        public int AccumulatedLeakDamage { get; private set; }

        public int LastHitDamage { get; private set; }

        public BattleSnapshot Snapshot { get; private set; }

        public static bool TryCreate(SliceBattleContent content, out CombatSimulation simulation, out string error)
        {
            simulation = null;
            if (content == null || content.Tower == null || content.Enemy == null || content.Level == null)
            {
                error = "切片内容为空";
                return false;
            }

            if (content.Tower.Id != SliceRules.SliceTowerId || content.Tower.TargetPriority != SliceRules.TargetFirstAlongPath)
            {
                error = "M1 只能放置 tower_jin，且只实现 first_along_path";
                return false;
            }

            if (content.Level.WinRule != SliceRules.WinAllWavesCleared)
            {
                error = "M1 只实现 all_waves_cleared";
                return false;
            }

            if (content.Level.LoseRule != SliceRules.LoseLeakCount)
            {
                error = "M1 只实现 leak_count。形状样例的 leak_rule_tbd 不能开打。";
                return false;
            }

            try
            {
                simulation = new CombatSimulation(content);
            }
            catch (System.ArgumentException exception)
            {
                error = exception.Message + "，已保留原文件";
                return false;
            }

            error = null;
            return true;
        }

        public void EnqueuePlace(string towerId, string cellId)
        {
            _intents.Enqueue(new PlaceIntent(towerId ?? string.Empty, cellId ?? string.Empty));
            Publish();
        }

        public void Begin()
        {
            if (Phase == BattlePhase.Ready)
            {
                Phase = BattlePhase.Running;
                Publish();
            }
        }

        public void Tick()
        {
            if (Phase != BattlePhase.Running)
            {
                return;
            }

            TickCount++;
            LastHitDamage = 0;
            ApplyIntents();
            _waves.Tick(Spawn);
            Move();
            Attack();
            _hero.SettleTick();
            _capture.SettleTick();
            EvaluateOutcome();
            Publish();
        }

        private void ApplyIntents()
        {
            while (_intents.Count > 0)
            {
                var intent = _intents.Dequeue();
                if (intent.TowerId != _content.Tower.Id)
                {
                    SnapshotNote("M1 只能放置 " + _content.Tower.Id);
                    continue;
                }

                BuildCellDefinition cell = null;
                for (var i = 0; i < _content.Level.BuildCells.Count; i++)
                {
                    if (_content.Level.BuildCells[i].Id == intent.CellId)
                    {
                        cell = _content.Level.BuildCells[i];
                        break;
                    }
                }

                if (cell == null)
                {
                    SnapshotNote("没有这个可建造格");
                    continue;
                }

                var occupied = false;
                for (var i = 0; i < _towers.Count; i++)
                {
                    if (_towers[i].CellId == cell.Id)
                    {
                        occupied = true;
                        break;
                    }
                }

                if (occupied || _towers.Count > 0)
                {
                    SnapshotNote("金塔已经放下");
                    continue;
                }

                _towers.Add(new TowerState
                {
                    Id = _content.Tower.Id,
                    CellId = cell.Id,
                    X = cell.X,
                    Y = cell.Y,
                    Range = _content.Tower.Range,
                    Cooldown = 0,
                });
                SnapshotNote("已放置金塔");
            }
        }

        private void Spawn(string enemyId)
        {
            if (enemyId != _content.Enemy.Id)
            {
                SnapshotNote("波次引用了未加载的敌人 " + enemyId);
                return;
            }

            var origin = Path.Sample(0);
            _enemies.Add(new EnemyUnit
            {
                InstanceId = _nextEnemyId++,
                DefId = _content.Enemy.Id,
                Distance = 0,
                PreviousDistance = 0,
                X = origin.X,
                Y = origin.Y,
                Hp = _content.Enemy.MaxHp,
                MaxHp = _content.Enemy.MaxHp,
                Speed = _content.Enemy.Speed,
                LeakDamage = _content.Enemy.LeakDamage,
                Alive = true,
            });
        }

        private void Move()
        {
            for (var i = 0; i < _enemies.Count; i++)
            {
                var enemy = _enemies[i];
                if (!enemy.Alive)
                {
                    continue;
                }

                enemy.PreviousDistance = enemy.Distance;
                enemy.Distance += enemy.Speed;
                if (enemy.Distance + 1e-6 >= Path.Length)
                {
                    var end = Path.Sample(Path.Length);
                    enemy.Distance = Path.Length;
                    enemy.X = end.X;
                    enemy.Y = end.Y;
                    enemy.Alive = false;
                    LeakCount++;
                    AccumulatedLeakDamage += enemy.LeakDamage;
                }
                else
                {
                    var point = Path.Sample(enemy.Distance);
                    enemy.X = point.X;
                    enemy.Y = point.Y;
                }
            }

            _enemies.RemoveAll(enemy => !enemy.Alive);
        }

        private void Attack()
        {
            var damage = _content.Tower.Damage;
            for (var i = 0; i < _towers.Count; i++)
            {
                var tower = _towers[i];
                if (tower.Cooldown > 0)
                {
                    tower.Cooldown--;
                }

                if (tower.Cooldown != 0)
                {
                    continue;
                }

                var target = TowerTargeting.FirstAlongPath(_enemies, tower.X, tower.Y, tower.Range);
                if (target == null)
                {
                    continue;
                }

                // M1 没有元素表。未配置的克制不在代码里写倍率，伤害就是表上的 damage。
                target.Hp -= damage;
                LastHitDamage = damage;
                tower.Cooldown = _content.Tower.AttackIntervalTicks;
                if (target.Hp <= 0)
                {
                    target.Alive = false;
                }
            }

            _enemies.RemoveAll(enemy => !enemy.Alive);
        }

        private void EvaluateOutcome()
        {
            if (LeakCount >= _content.Level.LoseLeakCount)
            {
                Phase = BattlePhase.Lost;
                return;
            }

            if (_waves.Finished && _enemies.Count == 0)
            {
                Phase = BattlePhase.Won;
            }
        }

        private void Publish()
        {
            var snapshot = Snapshot ?? new BattleSnapshot();
            snapshot.Tick = TickCount;
            snapshot.Phase = Phase;
            snapshot.LeakCount = LeakCount;
            snapshot.AccumulatedLeakDamage = AccumulatedLeakDamage;
            snapshot.LoseLeakCount = _content.Level.LoseLeakCount;
            snapshot.LoseRule = _content.Level.LoseRule;
            snapshot.WinRule = _content.Level.WinRule;
            snapshot.WavesFinished = _waves.Finished;
            snapshot.Enemies.Clear();
            for (var i = 0; i < _enemies.Count; i++)
            {
                var enemy = _enemies[i];
                snapshot.Enemies.Add(new EnemyView
                {
                    InstanceId = enemy.InstanceId,
                    Distance = enemy.Distance,
                    X = enemy.X,
                    Y = enemy.Y,
                    Hp = enemy.Hp,
                    MaxHp = enemy.MaxHp,
                    Speed = enemy.Speed,
                });
            }

            snapshot.Towers.Clear();
            for (var i = 0; i < _towers.Count; i++)
            {
                var tower = _towers[i];
                snapshot.Towers.Add(new TowerView
                {
                    Id = tower.Id,
                    CellId = tower.CellId,
                    X = tower.X,
                    Y = tower.Y,
                    Range = tower.Range,
                });
            }

            snapshot.Cells.Clear();
            for (var i = 0; i < _content.Level.BuildCells.Count; i++)
            {
                var cell = _content.Level.BuildCells[i];
                var occupied = false;
                for (var t = 0; t < _towers.Count; t++)
                {
                    if (_towers[t].CellId == cell.Id)
                    {
                        occupied = true;
                        break;
                    }
                }

                var queued = false;
                foreach (var intent in _intents)
                {
                    if (intent.CellId == cell.Id && intent.TowerId == _content.Tower.Id)
                    {
                        queued = true;
                        break;
                    }
                }

                snapshot.Cells.Add(new CellView
                {
                    Id = cell.Id,
                    X = cell.X,
                    Y = cell.Y,
                    Occupied = occupied,
                    Queued = queued,
                });
            }

            Snapshot = snapshot;
        }

        private void SnapshotNote(string note)
        {
            if (Snapshot == null)
            {
                Snapshot = new BattleSnapshot();
            }

            Snapshot.Note = note;
        }

        private struct PlaceIntent
        {
            public PlaceIntent(string towerId, string cellId)
            {
                TowerId = towerId;
                CellId = cellId;
            }

            public string TowerId;
            public string CellId;
        }

        private sealed class TowerState
        {
            public string Id;
            public string CellId;
            public double X;
            public double Y;
            public double Range;
            public int Cooldown;
        }
    }
}
