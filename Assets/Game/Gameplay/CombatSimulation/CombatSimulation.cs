using System;
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
        public int WaveIndex;
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
        public int Balance;
        public string CurrencyId;
        public int WaveNumber;
        public int WaveCount;
        public List<EnemyView> Enemies = new List<EnemyView>();
        public List<TowerView> Towers = new List<TowerView>();
        public List<CellView> Cells = new List<CellView>();
        public List<SwordView> Swords = new List<SwordView>();
    }

    /// <summary>
    /// 一拍结束时的飞剑。Previous 是上一拍结束的位置，X/Y 是这一拍结束的位置。
    /// 命中或消散的那一拍仍然出现在快照里，下一拍移除。
    /// </summary>
    public sealed class SwordView
    {
        public int Id;
        public string CellId;
        public int TargetId;
        public double PreviousX;
        public double PreviousY;
        public double X;
        public double Y;
        public double AimX;
        public double AimY;
        public double Traveled;
        public int Damage;
        public bool Active;
        public bool TargetLost;
        public bool SpawnedThisTick;
        public bool HitThisTick;
        public bool DissipatedThisTick;
    }

    /// <summary>
    /// 一拍里的飞剑事件。表现层可能一帧消化多个 tick，所以事件留到被取走，不在下一拍清掉。
    /// </summary>
    public sealed class SwordImpact
    {
        public int Id;
        public string CellId;
        public int TargetId;
        public double X;
        public double Y;
        public bool Spawned;
        public bool Hit;
        public bool Dissipated;
    }

    /// <summary>
    /// 固定 tick 的权威对局。倍速不进这个类：调用方决定一帧调用几次 Tick。
    /// 单次伤害始终是塔表上的 damage，不乘元素表（本关没有元素表）。
    /// 每座建造格最多一座 tower_jin。冀州 01 有 3 格，因此最多 3 座。
    /// 建造扣 economy.buildCost；余额不足则不放、不扣。
    /// 击杀加 enemy.reward（货币须与关卡 economy.currencyId 一致）。漏出不加。
    /// 波清奖：该波已刷完，且该波每只敌人都已击杀或漏出后发放一次，
    /// 金额 = waveClearBase + waveClearPerWaveIndex × (波序号 − 1)，波序号从 1 起。
    /// 漏出仍算该波已结算，所以有漏也会发波清奖。数值表的终局 640 按全程击杀、0 漏计算。
    /// 胜负只看漏出只数，不看 AccumulatedLeakDamage。
    /// 攻击是追踪飞剑，不是即时命中。开火拍只生成飞剑，伤害和击杀奖励在命中拍结算。
    /// 飞剑每 tick 朝目标当前位置移动，剩余距离 ≤ projectileSpeed 则命中。不锁开火点，也不用命中半径。
    /// 目标已死或已漏则飞向最后位置并消散，不换目标。索敌把在途且仍可能命中的伤害算进预定：
    /// 当前生命 − 预定 ≤ 0 的敌人跳过；范围内都被预定则本拍不开火、冷却不加。允许打出过量伤害。在途数量不设上限。
    /// 弹速取塔表 projectileSpeed，低于 0.04 高度单位/tick 的表在加载时拒绝。倍速不进这个类。
    /// </summary>
    public sealed class CombatSimulation
    {
        public const string NoteInsufficientLingshi = "灵石不足";
        public const string NoteCellTaken = "建造格已占用";
        public const string NotePlaced = "已放置剑阵";
        public const string NoteBattleOver = "战斗已结束";

        /// <summary>与 <see cref="SliceRules.MinProjectileSpeedPerTick"/> 相同，方便模拟侧直接引用。</summary>
        public const double MinProjectileSpeedPerTick = SliceRules.MinProjectileSpeedPerTick;

        private readonly SliceBattleContent _content;
        private readonly WaveDirector _waves;
        private readonly List<EnemyUnit> _enemies = new List<EnemyUnit>();
        private readonly List<TowerState> _towers = new List<TowerState>();
        private readonly Queue<PlaceIntent> _intents = new Queue<PlaceIntent>();
        private readonly IHeroActions _hero = new IdleHero();
        private readonly ICaptureRules _capture = new IdleCapture();
        private readonly int[] _spawnedByWave;
        private readonly int[] _resolvedByWave;
        private readonly int[] _waveClearAmounts;
        private readonly bool[] _waveClearPaid;
        private readonly List<SwordShot> _swords = new List<SwordShot>();
        private readonly List<SwordShot> _endedSwords = new List<SwordShot>();
        private readonly List<SwordImpact> _impacts = new List<SwordImpact>();
        private int _nextEnemyId = 1;
        private int _nextSwordId = 1;

        private CombatSimulation(SliceBattleContent content)
        {
            if (content.Level.Economy == null)
            {
                throw new ArgumentException("关卡缺少 economy");
            }

            _content = content;
            Path = new PathCurve(content.Level.Waypoints);
            _waves = new WaveDirector(content.Level);
            var waveCount = content.Level.Waves.Count;
            _spawnedByWave = new int[waveCount];
            _resolvedByWave = new int[waveCount];
            _waveClearAmounts = new int[waveCount];
            _waveClearPaid = new bool[waveCount];
            Balance = content.Level.Economy.StartingAmount;
            Phase = BattlePhase.Ready;
            Publish();
        }

        public PathCurve Path { get; }

        public BattlePhase Phase { get; private set; }

        public int TickCount { get; private set; }

        public int LeakCount { get; private set; }

        public int AccumulatedLeakDamage { get; private set; }

        public int LastHitDamage { get; private set; }

        public int Balance { get; private set; }

        public int TotalBuildSpent { get; private set; }

        public int KilledEnemies { get; private set; }

        public int TotalKillRewards { get; private set; }

        public int TotalWaveClearRewards { get; private set; }

        /// <summary>飞到最后位置后消散、没有造成伤害的飞剑。</summary>
        public int DissipatedSwords { get; private set; }

        /// <summary>范围内有敌人，但每只都被在途伤害预定致死，本拍没有开火的次数。</summary>
        public int ReservedHoldShots { get; private set; }

        /// <summary>取出并清空自上次调用以来的飞剑事件。表现层用来补上一帧里的多个 tick。</summary>
        public void CopySwordImpacts(List<SwordImpact> into)
        {
            if (into == null)
            {
                return;
            }

            for (var i = 0; i < _impacts.Count; i++)
            {
                into.Add(_impacts[i]);
            }

            _impacts.Clear();
        }

        public BattleSnapshot Snapshot { get; private set; }

        public static int ScaleMaxHp(int baseHp, double multiplier)
        {
            var scaled = Math.Round(baseHp * multiplier, MidpointRounding.AwayFromZero);
            if (scaled < 1)
            {
                return 1;
            }

            if (scaled > int.MaxValue)
            {
                return int.MaxValue;
            }

            return (int)scaled;
        }

        public int WaveClearAmount(int waveIndex)
        {
            if (waveIndex < 0 || waveIndex >= _waveClearAmounts.Length)
            {
                return 0;
            }

            return _waveClearAmounts[waveIndex];
        }

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
                error = "只能放置 tower_jin，且只实现 first_along_path";
                return false;
            }

            if (content.Level.WinRule != SliceRules.WinAllWavesCleared)
            {
                error = "只实现 all_waves_cleared";
                return false;
            }

            if (content.Level.LoseRule != SliceRules.LoseLeakCount)
            {
                error = "只实现 leak_count。形状样例的 leak_rule_tbd 不能开打。";
                return false;
            }

            if (content.Level.Economy == null || string.IsNullOrEmpty(content.Level.Economy.CurrencyId))
            {
                error = "关卡缺少 economy";
                return false;
            }

            if (!(content.Tower.ProjectileSpeed >= MinProjectileSpeedPerTick))
            {
                error = "弹速必须 ≥ 0.04 高度单位/tick";
                return false;
            }

            try
            {
                simulation = new CombatSimulation(content);
            }
            catch (ArgumentException exception)
            {
                error = exception.Message + "，已保留原文件";
                return false;
            }

            error = null;
            return true;
        }

        public void EnqueuePlace(string towerId, string cellId)
        {
            if (Phase != BattlePhase.Ready && Phase != BattlePhase.Running)
            {
                SnapshotNote(NoteBattleOver);
                Publish();
                return;
            }

            var reason = QueueRejectReason(towerId ?? string.Empty, cellId ?? string.Empty);
            if (reason != null)
            {
                SnapshotNote(reason);
                Publish();
                return;
            }

            _intents.Enqueue(new PlaceIntent(towerId ?? string.Empty, cellId ?? string.Empty));
            if (Snapshot != null && Snapshot.Note == NoteInsufficientLingshi)
            {
                Snapshot.Note = null;
            }

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

            // TickCount 先加。开战前 EnqueuePlace 的塔在本拍 ApplyIntents 落地（第一次 Tick 即 tick 1），
            // 同一拍可以开火。不要改成 tick 0 落地。
            TickCount++;
            LastHitDamage = 0;
            _endedSwords.Clear();
            ApplyIntents();
            _waves.Tick(Spawn);
            // 刷怪仍在移动之前，新敌人本拍会走一步。
            // 然后：敌人移动/漏怪 → 飞剑按创建序移动与命中 → 塔选目标并发射 → 下面的波次/经济。
            // 建造意图留在拍首，是因为 tick 1 落地已经是现行口径，不宜挪到发射之后。
            Move();
            FlySwords();
            _enemies.RemoveAll(enemy => !enemy.Alive);
            FireSwords();
            GrantWaveClears();
            _hero.SettleTick();
            _capture.SettleTick();
            EvaluateOutcome();
            Publish();
        }

        private string QueueRejectReason(string towerId, string cellId)
        {
            if (towerId != _content.Tower.Id)
            {
                return "只能放置 " + _content.Tower.Id;
            }

            if (FindCell(cellId) == null)
            {
                return "没有这个可建造格";
            }

            if (CellTaken(cellId))
            {
                return NoteCellTaken;
            }

            var cost = _content.Tower.BuildCost;
            if (Balance < cost + QueuedCost())
            {
                return NoteInsufficientLingshi;
            }

            return null;
        }

        private int QueuedCost()
        {
            var cost = _content.Tower.BuildCost;
            var total = 0;
            foreach (var intent in _intents)
            {
                if (intent.TowerId == _content.Tower.Id && FindCell(intent.CellId) != null && !TowerOnCell(intent.CellId))
                {
                    total += cost;
                }
            }

            return total;
        }

        private bool CellTaken(string cellId)
        {
            if (TowerOnCell(cellId))
            {
                return true;
            }

            foreach (var intent in _intents)
            {
                if (intent.CellId == cellId && intent.TowerId == _content.Tower.Id)
                {
                    return true;
                }
            }

            return false;
        }

        private void ApplyIntents()
        {
            var placed = 0;
            var rejectedFunds = false;
            while (_intents.Count > 0)
            {
                var intent = _intents.Dequeue();
                if (intent.TowerId != _content.Tower.Id)
                {
                    SnapshotNote("只能放置 " + _content.Tower.Id);
                    continue;
                }

                var cell = FindCell(intent.CellId);
                if (cell == null)
                {
                    SnapshotNote("没有这个可建造格");
                    continue;
                }

                if (TowerOnCell(cell.Id))
                {
                    SnapshotNote(NoteCellTaken);
                    continue;
                }

                var cost = _content.Tower.BuildCost;
                if (Balance < cost)
                {
                    SnapshotNote(NoteInsufficientLingshi);
                    rejectedFunds = true;
                    continue;
                }

                Balance -= cost;
                TotalBuildSpent += cost;
                _towers.Add(new TowerState
                {
                    Id = _content.Tower.Id,
                    CellId = cell.Id,
                    X = cell.X,
                    Y = cell.Y,
                    Range = _content.Tower.Range,
                    Cooldown = 0,
                });
                placed++;
            }

            if (placed > 0 && !rejectedFunds)
            {
                SnapshotNote(NotePlaced);
            }
        }

        private BuildCellDefinition FindCell(string cellId)
        {
            var cells = _content.Level.BuildCells;
            for (var i = 0; i < cells.Count; i++)
            {
                if (cells[i].Id == cellId)
                {
                    return cells[i];
                }
            }

            return null;
        }

        private bool TowerOnCell(string cellId)
        {
            for (var i = 0; i < _towers.Count; i++)
            {
                if (_towers[i].CellId == cellId)
                {
                    return true;
                }
            }

            return false;
        }

        private void Spawn(string enemyId, int waveIndex, double hpMultiplier)
        {
            if (enemyId != _content.Enemy.Id)
            {
                SnapshotNote("波次引用了未加载的敌人 " + enemyId);
                return;
            }

            if (hpMultiplier <= 0)
            {
                hpMultiplier = 1;
            }

            var maxHp = ScaleMaxHp(_content.Enemy.MaxHp, hpMultiplier);
            var origin = Path.Sample(0);
            _enemies.Add(new EnemyUnit
            {
                InstanceId = _nextEnemyId++,
                DefId = _content.Enemy.Id,
                WaveIndex = waveIndex,
                Distance = 0,
                PreviousDistance = 0,
                X = origin.X,
                Y = origin.Y,
                Hp = maxHp,
                MaxHp = maxHp,
                Speed = _content.Enemy.Speed,
                LeakDamage = _content.Enemy.LeakDamage,
                Alive = true,
            });
            if (waveIndex >= 0 && waveIndex < _spawnedByWave.Length)
            {
                _spawnedByWave[waveIndex]++;
            }
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
                    MarkResolved(enemy);
                }
                else
                {
                    var point = Path.Sample(enemy.Distance);
                    enemy.X = point.X;
                    enemy.Y = point.Y;
                }
            }

            // 不在这里移除。飞剑本拍还要读到漏怪后的终点坐标，移除放在 FlySwords 之后。
        }

        private void FlySwords()
        {
            for (var i = 0; i < _swords.Count; i++)
            {
                var sword = _swords[i];
                if (!sword.Active)
                {
                    continue;
                }

                sword.SpawnedThisTick = false;
                FlyOne(sword);
            }

            _swords.RemoveAll(sword => !sword.Active);
        }

        private void FlyOne(SwordShot sword)
        {
            sword.PreviousX = sword.X;
            sword.PreviousY = sword.Y;
            var enemy = FindEnemy(sword.TargetId);
            var canHit = enemy != null && enemy.Alive && !sword.TargetLost;
            if (enemy != null)
            {
                sword.AimX = enemy.X;
                sword.AimY = enemy.Y;
            }

            if (!canHit)
            {
                sword.TargetLost = true;
            }

            var speed = _content.Tower.ProjectileSpeed;
            var dx = sword.AimX - sword.X;
            var dy = sword.AimY - sword.Y;
            var dist = Math.Sqrt((dx * dx) + (dy * dy));
            if (dist <= speed + 1e-9)
            {
                sword.Traveled += dist;
                sword.X = sword.AimX;
                sword.Y = sword.AimY;
                if (canHit)
                {
                    ApplySwordHit(sword, enemy);
                }
                else
                {
                    Retire(sword, false, true);
                }

                return;
            }

            var scale = speed / dist;
            sword.X += dx * scale;
            sword.Y += dy * scale;
            sword.Traveled += speed;
        }

        private void ApplySwordHit(SwordShot sword, EnemyUnit target)
        {
            // 不把生命钳到 0。伤害可以大于剩余生命，击杀奖励仍然只发一次。
            target.Hp -= sword.Damage;
            LastHitDamage = sword.Damage;
            Retire(sword, true, false);
            if (target.Hp <= 0 && target.Alive)
            {
                target.Alive = false;
                GrantKill();
                MarkResolved(target);
            }
        }

        private void FireSwords()
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

                var inRange = TowerTargeting.FirstAlongPath(_enemies, tower.X, tower.Y, tower.Range);
                var target = inRange;
                if (inRange != null)
                {
                    target = TowerTargeting.FirstAlongPath(_enemies, tower.X, tower.Y, tower.Range, StillNeedsDamage);
                }

                if (target == null)
                {
                    // 全部被预定则不开火，也不开始攻击间隔，下一拍再选。
                    if (inRange != null)
                    {
                        ReservedHoldShots++;
                    }

                    continue;
                }

                _swords.Add(new SwordShot
                {
                    Id = _nextSwordId++,
                    CellId = tower.CellId,
                    TargetId = target.InstanceId,
                    X = tower.X,
                    Y = tower.Y,
                    PreviousX = tower.X,
                    PreviousY = tower.Y,
                    AimX = target.X,
                    AimY = target.Y,
                    Damage = damage,
                    Active = true,
                    SpawnedThisTick = true,
                });
                tower.Cooldown = _content.Tower.AttackIntervalTicks;
                _impacts.Add(new SwordImpact
                {
                    Id = _swords[_swords.Count - 1].Id,
                    CellId = tower.CellId,
                    TargetId = target.InstanceId,
                    X = tower.X,
                    Y = tower.Y,
                    Spawned = true,
                });
            }
        }

        private bool StillNeedsDamage(EnemyUnit enemy)
        {
            return enemy.Hp - ReservedDamage(enemy.InstanceId) > 0;
        }

        private int ReservedDamage(int instanceId)
        {
            var reserved = 0;
            for (var i = 0; i < _swords.Count; i++)
            {
                var sword = _swords[i];
                if (sword.Active && !sword.TargetLost && sword.TargetId == instanceId)
                {
                    reserved += sword.Damage;
                }
            }

            return reserved;
        }

        private EnemyUnit FindEnemy(int instanceId)
        {
            for (var i = 0; i < _enemies.Count; i++)
            {
                if (_enemies[i].InstanceId == instanceId)
                {
                    return _enemies[i];
                }
            }

            return null;
        }

        private void Retire(SwordShot sword, bool hit, bool dissipate)
        {
            if (!sword.Active)
            {
                return;
            }

            sword.Active = false;
            sword.HitThisTick = hit;
            sword.DissipatedThisTick = dissipate;
            if (dissipate)
            {
                DissipatedSwords++;
            }

            _endedSwords.Add(sword);
            _impacts.Add(new SwordImpact
            {
                Id = sword.Id,
                CellId = sword.CellId,
                TargetId = sword.TargetId,
                X = sword.X,
                Y = sword.Y,
                Hit = hit,
                Dissipated = dissipate,
            });
        }

        private void AbandonDoomedSwords()
        {
            for (var i = 0; i < _swords.Count; i++)
            {
                var sword = _swords[i];
                if (!sword.Active)
                {
                    continue;
                }

                var enemy = FindEnemy(sword.TargetId);
                if (!sword.TargetLost && enemy != null && enemy.Alive)
                {
                    continue;
                }

                sword.Active = false;
            }

            _swords.RemoveAll(sword => !sword.Active);
        }

        private void GrantKill()
        {
            KilledEnemies++;
            var reward = _content.Enemy;
            var economy = _content.Level.Economy;
            if (reward.RewardAmount <= 0 || reward.RewardCurrencyId != economy.CurrencyId)
            {
                return;
            }

            Balance += reward.RewardAmount;
            TotalKillRewards += reward.RewardAmount;
        }

        private void MarkResolved(EnemyUnit enemy)
        {
            var wave = enemy.WaveIndex;
            if (wave >= 0 && wave < _resolvedByWave.Length)
            {
                _resolvedByWave[wave]++;
            }
        }

        /// <summary>
        /// 清场：该波已全部刷出，且每一只都已结算（击杀或漏入终点）才发放波次奖励。
        /// 漏入不发击杀奖，但计入清场。
        /// </summary>
        private void GrantWaveClears()
        {
            var economy = _content.Level.Economy;
            var done = _waves.SpawnedWaveCount;
            for (var wave = 0; wave < done && wave < _waveClearPaid.Length; wave++)
            {
                if (_waveClearPaid[wave])
                {
                    continue;
                }

                if (_spawnedByWave[wave] <= 0 || _resolvedByWave[wave] < _spawnedByWave[wave])
                {
                    continue;
                }

                var waveNumber = wave + 1;
                var amount = economy.WaveClearBase + (economy.WaveClearPerWaveIndex * (waveNumber - 1));
                Balance += amount;
                TotalWaveClearRewards += amount;
                _waveClearAmounts[wave] = amount;
                _waveClearPaid[wave] = true;
            }
        }

        private void EvaluateOutcome()
        {
            var before = Phase;
            if (LeakCount >= _content.Level.LoseLeakCount)
            {
                Phase = BattlePhase.Lost;
            }
            else if (_waves.Finished && _enemies.Count == 0)
            {
                Phase = BattlePhase.Won;
            }

            if (Phase != before)
            {
                AbandonDoomedSwords();
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
            snapshot.Balance = Balance;
            snapshot.CurrencyId = _content.Level.Economy.CurrencyId;
            snapshot.WaveNumber = _waves.CurrentWaveNumber;
            snapshot.WaveCount = _waves.WaveCount;
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

            snapshot.Swords.Clear();
            PublishSwords(snapshot, _swords);
            PublishSwords(snapshot, _endedSwords);

            snapshot.Cells.Clear();
            for (var i = 0; i < _content.Level.BuildCells.Count; i++)
            {
                var cell = _content.Level.BuildCells[i];
                var occupied = TowerOnCell(cell.Id);
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

        private static void PublishSwords(BattleSnapshot snapshot, List<SwordShot> swords)
        {
            for (var i = 0; i < swords.Count; i++)
            {
                var sword = swords[i];
                snapshot.Swords.Add(new SwordView
                {
                    Id = sword.Id,
                    CellId = sword.CellId,
                    TargetId = sword.TargetId,
                    PreviousX = sword.PreviousX,
                    PreviousY = sword.PreviousY,
                    X = sword.X,
                    Y = sword.Y,
                    AimX = sword.AimX,
                    AimY = sword.AimY,
                    Traveled = sword.Traveled,
                    Damage = sword.Damage,
                    Active = sword.Active,
                    TargetLost = sword.TargetLost,
                    SpawnedThisTick = sword.SpawnedThisTick,
                    HitThisTick = sword.HitThisTick,
                    DissipatedThisTick = sword.DissipatedThisTick,
                });
            }
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

        private sealed class SwordShot
        {
            public int Id;
            public string CellId;
            public int TargetId;
            public bool TargetLost;
            public bool Active;
            public bool SpawnedThisTick;
            public bool HitThisTick;
            public bool DissipatedThisTick;
            public double PreviousX;
            public double PreviousY;
            public double X;
            public double Y;
            public double AimX;
            public double AimY;
            public double Traveled;
            public int Damage;
        }
    }
}
