using System;
using System.Collections.Generic;
using System.IO;
using ShanhaiDingGuard.Content;
using ShanhaiDingGuard.Gameplay.CombatSimulation;
using ShanhaiDingGuard.Meta;
using ShanhaiDingGuard.Services.CloudSave;

internal static class Program
{
    private static int Main()
    {
        var root = FindRoot();
        var failures = new List<string>();
        CheckExamplesStayPlaceholders(root, failures);
        CheckSliceFilesMatchStreaming(root, failures);
        CheckSliceIdAccepted(root, failures);
        SliceBattleContent content = null;
        string error = null;
        if (!TryLoadSlice(root, out content, out error))
        {
            failures.Add("slice load: " + error);
        }
        else
        {
            CheckShape(content, failures);
            CheckBattleBackground(root, content, failures);
            CheckBattleArt(root, failures);
            CheckSpace(root, failures);
            CheckHpMultiplierDefault(root, failures);
            CheckOneTowerLoses(content, "cell_jin_01", OneTowerLoseTicksBaseline, 321, 1751, failures);
            CheckOneTowerLoses(content, "cell_jin_02", OneTowerCell02LoseTicksBaseline, 449, 2099, failures);
            CheckOneTowerLoses(content, "cell_jin_03", OneTowerCell03LoseTicksBaseline, 313, 1717, failures);
            CheckLose(content, failures);
            CheckSpeedDoesNotChangeDamageOrTickCount(content, failures);
            CheckTickBeforeBeginDoesNothing(content, failures);
            CheckEconomy(content, failures);
            CheckTwoTowers(content, failures);
            CheckThreeTowers(content, failures);
            CheckWaveClearPaysWhenLeaked(content, failures);
        }

        CheckLevelProgressRoundTrip(failures);
        if (failures.Count > 0)
        {
            Console.Error.WriteLine("M1 slice check failed:");
            for (var i = 0; i < failures.Count; i++)
            {
                Console.Error.WriteLine(" - " + failures[i]);
            }

            return 1;
        }

        Console.WriteLine("M1 slice check passed.");
        for (var i = 0; i < Notes.Count; i++)
        {
            Console.WriteLine(Notes[i]);
        }

        return 0;
    }

    private static readonly List<string> Notes = new List<string>();

    /// <summary>
    /// tick 基线取 m1-slice-check 的 C# 实测，断言为该值的 ±5%。灵石和漏怪数是精确值。
    /// 当康 maxHp=60。Nora 模拟：无塔判负 943；1 塔 01/02/03 判负 1751/2099/1717；2 塔与 3 塔通关 1932。
    /// C# 实测：无塔 946；1 塔 01/02/03 判负 1806/2135/1775，余额 321/449/313；2 塔与 3 塔通关 1977，余额 540/440。
    /// </summary>
    private const int OneTowerLoseTicksBaseline = 1806;

    private const int OneTowerCell02LoseTicksBaseline = 2135;

    private const int OneTowerCell03LoseTicksBaseline = 1775;

    private const int NoTowerLoseTicksBaseline = 946;

    private const int TwoTowerClearTicksBaseline = 1977;

    private const int ThreeTowerClearTicksBaseline = 1977;

    /// <summary>
    /// 三塔按这个格子顺序建造。选择不跟建造格表或快照的遍历顺序走。
    /// </summary>
    private static readonly string[] ThreeTowerBuildOrder =
    {
        "cell_jin_01",
        "cell_jin_02",
        "cell_jin_03",
    };

    private const double TickTolerance = 0.05;

    private static readonly double[] ExpectedPathX =
    {
        1.470, 1.240, 0.980, 0.700, 0.480, 0.390, 0.400, 0.600, 0.880, 1.160, 1.420,
        1.520, 1.360, 1.060, 0.740, 0.440, 0.270, 0.330, 0.660, 1.000, 1.300, 1.530,
    };

    private static readonly double[] ExpectedPathY =
    {
        0.870, 0.820, 0.860, 0.790, 0.800, 0.700, 0.600, 0.550, 0.610, 0.570, 0.580,
        0.480, 0.380, 0.400, 0.340, 0.390, 0.300, 0.170, 0.190, 0.140, 0.200, 0.230,
    };

    private static void CheckExamplesStayPlaceholders(string root, List<string> failures)
    {
        var level = File.ReadAllText(Path.Combine(root, "content", "examples", "level_jizhou_01_waves.json"));
        var tower = File.ReadAllText(Path.Combine(root, "content", "examples", "tower_jin.json"));
        var enemy = File.ReadAllText(Path.Combine(root, "content", "examples", "enemy_dangkang.json"));
        if (level.IndexOf("\"lose\": \"leak_rule_tbd\"", StringComparison.Ordinal) < 0)
        {
            failures.Add("example level lose rule was redefined");
        }

        if (level.IndexOf("\"count\": null", StringComparison.Ordinal) < 0 || tower.IndexOf("\"damage\": null", StringComparison.Ordinal) < 0)
        {
            failures.Add("example numbers were filled in");
        }

        string ignored;
        TowerDefinition towerDef;
        EnemyDefinition enemyDef;
        LevelDefinition levelDef;
        if (SliceTables.TryParseTower(tower, out towerDef, out ignored))
        {
            failures.Add("example tower should not be playable");
        }

        if (SliceTables.TryParseEnemy(enemy, out enemyDef, out ignored))
        {
            failures.Add("example enemy should not be playable");
        }

        if (SliceTables.TryParseLevel(level, out levelDef, out ignored))
        {
            failures.Add("example level should not be playable");
        }
    }

    private static void CheckSliceFilesMatchStreaming(string root, List<string> failures)
    {
        var pairs = new[]
        {
            new[] { "towers/tower_jin.json", "towers/tower_jin.json" },
            new[] { "enemies/enemy_dangkang.json", "enemies/enemy_dangkang.json" },
            new[] { "levels/level_jizhou_01.json", "levels/level_jizhou_01.json" },
        };
        for (var i = 0; i < pairs.Length; i++)
        {
            var authored = File.ReadAllBytes(Path.Combine(root, "content", pairs[i][0]));
            var streamed = File.ReadAllBytes(Path.Combine(root, "Assets", "StreamingAssets", "shdg", pairs[i][1]));
            if (authored.Length != streamed.Length)
            {
                failures.Add("streaming copy differs: " + pairs[i][0]);
                continue;
            }

            for (var b = 0; b < authored.Length; b++)
            {
                if (authored[b] != streamed[b])
                {
                    failures.Add("streaming copy differs: " + pairs[i][0]);
                    break;
                }
            }
        }
    }

    private static bool TryLoadSlice(string root, out SliceBattleContent content, out string error)
    {
        var tower = File.ReadAllText(Path.Combine(root, "content", "towers", "tower_jin.json"));
        var enemy = File.ReadAllText(Path.Combine(root, "content", "enemies", "enemy_dangkang.json"));
        var level = File.ReadAllText(Path.Combine(root, "content", "levels", "level_jizhou_01.json"));
        return SliceTables.TryParse(tower, enemy, level, SliceRules.SliceLevelId, out content, out error);
    }

    private static void CheckSliceIdAccepted(string root, List<string> failures)
    {
        var towerPath = Path.Combine(root, "content", "towers", "tower_jin.json");
        var levelPath = Path.Combine(root, "content", "levels", "level_jizhou_01.json");
        var enemyPath = Path.Combine(root, "content", "enemies", "enemy_dangkang.json");
        var tower = File.ReadAllText(towerPath);
        var level = File.ReadAllText(levelPath);
        var enemy = File.ReadAllText(enemyPath);
        if (tower.IndexOf("\"slice\": \"jizhou_01_formal\"", StringComparison.Ordinal) < 0
            || level.IndexOf("\"slice\": \"jizhou_01_formal\"", StringComparison.Ordinal) < 0
            || enemy.IndexOf("\"slice\": \"jizhou_01_formal\"", StringComparison.Ordinal) < 0)
        {
            failures.Add("formal tables are not marked slice jizhou_01_formal");
        }

        string error;
        TowerDefinition towerDef;
        var asM1 = tower.Replace("\"slice\": \"jizhou_01_formal\"", "\"slice\": \"m1\"");
        if (!SliceTables.TryParseTower(asM1, out towerDef, out error))
        {
            failures.Add("slice m1 should still load: " + error);
        }

        var unknown = tower.Replace("\"slice\": \"jizhou_01_formal\"", "\"slice\": \"example\"");
        if (SliceTables.TryParseTower(unknown, out towerDef, out error))
        {
            failures.Add("unknown slice should be rejected");
        }
    }

    private static void CheckShape(SliceBattleContent content, List<string> failures)
    {
        if (content.Level.Waves.Count != 8)
        {
            failures.Add("expected 8 waves, got " + content.Level.Waves.Count);
        }

        if (content.Level.Waypoints.Count < 2)
        {
            failures.Add("path is missing waypoints");
        }

        if (content.Level.BuildCells.Count != 3)
        {
            failures.Add("expected 3 build cells, got " + content.Level.BuildCells.Count);
        }
        else if (content.Level.BuildCells[0].Id != "cell_jin_01"
            || content.Level.BuildCells[1].Id != "cell_jin_02"
            || content.Level.BuildCells[2].Id != "cell_jin_03")
        {
            failures.Add("build cell ids drifted");
        }

        if (content.Enemy.Element != null)
        {
            failures.Add("enemy element should stay null");
        }

        if (content.Tower.TargetPriority != SliceRules.TargetFirstAlongPath)
        {
            failures.Add("target priority drifted");
        }

        if (content.Tower.Damage != 10 || content.Tower.AttackIntervalTicks != 8)
        {
            failures.Add("tower damage/interval drifted from 10 / 8");
        }

        if (Math.Abs(content.Tower.Range - 0.28) > 1e-9)
        {
            failures.Add("tower range drifted from 0.28 height units");
        }

        if (Math.Abs(content.Enemy.Speed - 0.006) > 1e-12)
        {
            failures.Add("dangkang speed drifted from 0.006 per tick, got " + content.Enemy.Speed);
        }

        if (content.Level.Space != SliceRules.SpaceHeightUnits16x9)
        {
            failures.Add("level space is not height_units_16x9");
        }

        if (content.Level.Waypoints.Count != ExpectedPathX.Length)
        {
            failures.Add("expected " + ExpectedPathX.Length + " waypoints, got " + content.Level.Waypoints.Count);
            return;
        }

        for (var i = 0; i < ExpectedPathX.Length; i++)
        {
            var id = "wp_" + i.ToString("00");
            if (!ExpectPoint(content.Level.Waypoints, i, id, ExpectedPathX[i], ExpectedPathY[i], failures))
            {
                return;
            }
        }

        if (!ExpectCell(content.Level.BuildCells, 0, "cell_jin_01", 0.660, 0.690, failures)
            || !ExpectCell(content.Level.BuildCells, 1, "cell_jin_02", 1.130, 0.300, failures)
            || !ExpectCell(content.Level.BuildCells, 2, "cell_jin_03", 0.520, 0.280, failures))
        {
            return;
        }

        var path = new ShanhaiDingGuard.Gameplay.Path.PathCurve(content.Level.Waypoints);
        if (Math.Abs(path.Length - 5.086) > 0.0005)
        {
            failures.Add("path length " + path.Length.ToString("0.0000") + " is not about 5.086");
        }
        else
        {
            Notes.Add("path length=" + path.Length.ToString("0.0000"));
        }

        if (content.Tower.BuildCost != 100)
        {
            failures.Add("build cost drifted from 100");
        }

        if (content.Enemy.MaxHp != 60 || content.Enemy.RewardAmount != 8 || content.Enemy.RewardCurrencyId != "lingshi")
        {
            failures.Add("enemy hp or lingshi reward drifted");
        }

        if (content.Enemy.LeakDamage != 1)
        {
            failures.Add("leakDamage must stay 1 so leak count matches 铜鼎 hearts");
        }

        if (content.Level.LoseRule != SliceRules.LoseLeakCount || content.Level.LoseLeakCount != 3)
        {
            failures.Add("lose rule is not leak_count 3");
        }

        var economy = content.Level.Economy;
        if (economy == null
            || economy.CurrencyId != "lingshi"
            || economy.StartingAmount != 120
            || economy.WaveClearBase != 15
            || economy.WaveClearPerWaveIndex != 5)
        {
            failures.Add("level economy is not lingshi 120 / 15 + 5*(w-1)");
        }

        var enemies = 0;
        for (var i = 0; i < content.Level.Waves.Count; i++)
        {
            var spawn = content.Level.Waves[i].Spawns[0];
            enemies += spawn.Count;
            var expectedMultiplier = i == 7 ? 1.1 : 1.0;
            if (Math.Abs(spawn.HpMultiplier - expectedMultiplier) > 1e-9)
            {
                failures.Add("wave " + (i + 1) + " hpMultiplier " + spawn.HpMultiplier);
            }
        }

        if (enemies != 45)
        {
            failures.Add("expected 45 enemies, got " + enemies);
        }

        if (CombatSimulation.ScaleMaxHp(60, 1.1) != 66 || CombatSimulation.ScaleMaxHp(60, 1.0) != 60)
        {
            failures.Add("hp scale round failed");
        }
    }

    private static void CheckHpMultiplierDefault(string root, List<string> failures)
    {
        var level = File.ReadAllText(Path.Combine(root, "content", "levels", "level_jizhou_01.json"));
        var stripped = level.Replace(", \"hpMultiplier\": 1.0", string.Empty).Replace(", \"hpMultiplier\": 1.1", string.Empty);
        var tower = File.ReadAllText(Path.Combine(root, "content", "towers", "tower_jin.json"));
        var enemy = File.ReadAllText(Path.Combine(root, "content", "enemies", "enemy_dangkang.json"));
        SliceBattleContent content;
        string error;
        if (!SliceTables.TryParse(tower, enemy, stripped, SliceRules.SliceLevelId, out content, out error))
        {
            failures.Add("missing hpMultiplier should default: " + error);
            return;
        }

        for (var i = 0; i < content.Level.Waves.Count; i++)
        {
            if (Math.Abs(content.Level.Waves[i].Spawns[0].HpMultiplier - 1.0) > 1e-9)
            {
                failures.Add("missing hpMultiplier did not default to 1");
                return;
            }
        }
    }

    private static void CheckOneTowerLoses(SliceBattleContent content, string cellId, int tickBaseline, int expectedBalance, int designTicks, List<string> failures)
    {
        var sim = StartPlacedOn(content, cellId);
        var hits = new List<int>();
        var leakTicks = new List<int>();
        var saw60 = false;
        var saw66 = false;
        var guard = 0;
        var previousLeaks = 0;
        while (sim.Phase == BattlePhase.Running && guard++ < 20000)
        {
            sim.Tick();
            if (sim.LeakCount > previousLeaks)
            {
                leakTicks.Add(sim.TickCount);
                previousLeaks = sim.LeakCount;
            }

            if (sim.LastHitDamage != 0)
            {
                hits.Add(sim.LastHitDamage);
            }

            var enemies = sim.Snapshot.Enemies;
            for (var i = 0; i < enemies.Count; i++)
            {
                if (enemies[i].MaxHp == 60)
                {
                    saw60 = true;
                }

                if (enemies[i].MaxHp == 66)
                {
                    saw66 = true;
                }
            }
        }

        if (sim.Phase != BattlePhase.Lost)
        {
            failures.Add(cellId + " one tower should lose, phase=" + sim.Phase + " tick=" + sim.TickCount + " leaks=" + sim.LeakCount + " alive=" + sim.Snapshot.Enemies.Count + " leakTicks=" + Join(leakTicks) + " balance=" + sim.Balance);
            return;
        }

        Notes.Add("lose: 1 tower " + cellId + ", leaks=" + sim.LeakCount + ", leakTicks=" + leakTicks.Count + " (" + Join(leakTicks) + "), ticks=" + sim.TickCount + " (" + (sim.TickCount * SimClock.TickSeconds).ToString("0.0") + "s at 1x), balance=" + sim.Balance + ", designTicks=" + designTicks + ", delta=" + (sim.TickCount - designTicks));

        if (leakTicks.Count != 3 || sim.LeakCount != 3 || sim.TickCount != leakTicks[2])
        {
            failures.Add(cellId + " loss was not exactly the 3rd leak: leaks=" + sim.LeakCount + " tick=" + sim.TickCount + " leakTicks=" + Join(leakTicks) + " leakTickCount=" + leakTicks.Count);
        }

        if (sim.Snapshot.Towers.Count != 1 || sim.Snapshot.Towers[0].CellId != cellId || sim.TotalBuildSpent != 100)
        {
            failures.Add(cellId + " expected one tower and spend 100, towers=" + sim.Snapshot.Towers.Count + " spent=" + sim.TotalBuildSpent);
        }

        if (sim.Balance != expectedBalance)
        {
            failures.Add(cellId + " final balance " + sim.Balance + " != " + expectedBalance);
        }

        if (!WithinTickTolerance(sim.TickCount, tickBaseline))
        {
            failures.Add(cellId + " lose ticks " + sim.TickCount + " outside ±5% of calibrated " + tickBaseline);
        }

        if (hits.Count == 0)
        {
            failures.Add(cellId + " tower never fired");
        }

        for (var i = 0; i < hits.Count; i++)
        {
            if (hits[i] != content.Tower.Damage || hits[i] != 10)
            {
                failures.Add(cellId + " hit damage " + hits[i] + " != table damage " + content.Tower.Damage);
                break;
            }
        }

        if (!saw60 || !saw66)
        {
            failures.Add(cellId + " expected spawned maxHp 60 and wave-8 maxHp 66, saw60=" + saw60 + " saw66=" + saw66);
        }
    }

    private static void CheckLose(SliceBattleContent content, List<string> failures)
    {
        CombatSimulation sim;
        string error;
        if (!CombatSimulation.TryCreate(content, out sim, out error))
        {
            failures.Add(error);
            return;
        }

        sim.Begin();
        var guard = 0;
        var previousLeaks = 0;
        var thirdLeakTick = 0;
        while (sim.Phase == BattlePhase.Running && guard++ < 20000)
        {
            sim.Tick();
            if (sim.LeakCount > previousLeaks)
            {
                previousLeaks = sim.LeakCount;
                if (sim.LeakCount == 3)
                {
                    thirdLeakTick = sim.TickCount;
                }
            }
        }

        if (sim.Phase != BattlePhase.Lost)
        {
            failures.Add("no tower should lose, phase=" + sim.Phase + " tick=" + sim.TickCount + " leaks=" + sim.LeakCount);
            return;
        }

        if (sim.LeakCount != 3 || sim.LeakCount != content.Level.LoseLeakCount || sim.TickCount != thirdLeakTick)
        {
            failures.Add("loss was not exactly the 3rd leak: leaks=" + sim.LeakCount + " tick=" + sim.TickCount + " thirdLeakTick=" + thirdLeakTick);
        }
        else
        {
            Notes.Add("lose: no tower, leaks=3 at tick " + sim.TickCount + ", balance=" + sim.Balance + ", designTicks=943, delta=" + (sim.TickCount - 943));
            if (!WithinTickTolerance(sim.TickCount, NoTowerLoseTicksBaseline))
            {
                failures.Add("no-tower lose ticks " + sim.TickCount + " outside ±5% of calibrated " + NoTowerLoseTicksBaseline);
            }
        }

        if (sim.Balance != 120)
        {
            failures.Add("no-tower final balance " + sim.Balance + " != 120");
        }

        if (sim.AccumulatedLeakDamage != content.Enemy.LeakDamage * sim.LeakCount)
        {
            failures.Add("leakDamage was not handed to the lose rule");
        }
    }

    private static void CheckSpeedDoesNotChangeDamageOrTickCount(SliceBattleContent content, List<string> failures)
    {
        int frames1;
        int ticks1;
        BattlePhase phase1;
        int frames2;
        int ticks2;
        BattlePhase phase2;
        if (!RunClock(content, 1, out frames1, out ticks1, out phase1, failures) || !RunClock(content, 2, out frames2, out ticks2, out phase2, failures))
        {
            return;
        }

        if (ticks1 != ticks2 || phase1 != phase2)
        {
            failures.Add("2x changed the sim outcome ticks " + ticks1 + " vs " + ticks2 + " phase " + phase1 + " vs " + phase2);
            return;
        }

        if (!(frames2 < frames1 * 0.6) || !(frames2 > frames1 * 0.4))
        {
            failures.Add("2x wall frames " + frames2 + " were not about half of 1x " + frames1);
            return;
        }

        Notes.Add("speed: hit damage stays 10, phase=" + phase1 + ", ticks=" + ticks1 + ", 1x frames=" + frames1 + ", 2x frames=" + frames2);
    }

    private static bool RunClock(SliceBattleContent content, int speed, out int frames, out int ticks, out BattlePhase phase, List<string> failures)
    {
        frames = 0;
        ticks = 0;
        phase = BattlePhase.Ready;
        var sim = StartPlaced(content);
        var clock = new SimClock();
        clock.SetSpeed(speed);
        var guard = 0;
        while (sim.Phase == BattlePhase.Running && guard++ < 200000)
        {
            frames++;
            var step = clock.ConsumeTicks(1.0 / 60.0);
            for (var i = 0; i < step; i++)
            {
                sim.Tick();
                if (sim.LastHitDamage != 0 && (sim.LastHitDamage != 10 || sim.LastHitDamage != content.Tower.Damage))
                {
                    failures.Add("speed " + speed + " changed hit damage to " + sim.LastHitDamage);
                    return false;
                }
            }
        }

        ticks = sim.TickCount;
        phase = sim.Phase;
        if (sim.Phase != BattlePhase.Won && sim.Phase != BattlePhase.Lost)
        {
            failures.Add("speed " + speed + " did not finish, phase=" + sim.Phase);
            return false;
        }

        return true;
    }

    private static void CheckTickBeforeBeginDoesNothing(SliceBattleContent content, List<string> failures)
    {
        CombatSimulation sim;
        string error;
        if (!CombatSimulation.TryCreate(content, out sim, out error))
        {
            failures.Add(error);
            return;
        }

        sim.Tick();
        if (sim.TickCount != 0 || sim.Phase != BattlePhase.Ready)
        {
            failures.Add("tick before begin advanced the battle");
        }
    }

    private static CombatSimulation StartPlaced(SliceBattleContent content)
    {
        return StartPlacedOn(content, content.Level.BuildCells[0].Id);
    }

    private static CombatSimulation StartPlacedOn(SliceBattleContent content, string cellId)
    {
        CombatSimulation sim;
        string error;
        if (!CombatSimulation.TryCreate(content, out sim, out error))
        {
            throw new InvalidOperationException(error);
        }

        sim.EnqueuePlace(content.Tower.Id, cellId);
        sim.Begin();
        return sim;
    }

    private static CombatSimulation RunAffordableTowers(SliceBattleContent content, int towerLimit, List<int> leakTicks)
    {
        var sim = StartPlaced(content);
        var previousLeaks = 0;
        var guard = 0;
        while (sim.Phase == BattlePhase.Running && guard++ < 20000)
        {
            sim.Tick();
            if (sim.LeakCount > previousLeaks)
            {
                leakTicks.Add(sim.TickCount);
                previousLeaks = sim.LeakCount;
            }

            if (sim.Phase != BattlePhase.Running)
            {
                break;
            }

            if (sim.Snapshot.Towers.Count >= towerLimit)
            {
                continue;
            }

            if (sim.Balance < content.Tower.BuildCost)
            {
                continue;
            }

            string free = null;
            var cells = sim.Snapshot.Cells;
            for (var i = 0; i < cells.Count; i++)
            {
                if (!cells[i].Occupied && !cells[i].Queued)
                {
                    free = cells[i].Id;
                    break;
                }
            }

            if (free != null)
            {
                sim.EnqueuePlace(content.Tower.Id, free);
            }
        }

        return sim;
    }

    private static void CheckEconomy(SliceBattleContent content, List<string> failures)
    {
        CombatSimulation fresh;
        string error;
        if (!CombatSimulation.TryCreate(content, out fresh, out error))
        {
            failures.Add(error);
            return;
        }

        if (fresh.Balance != 120 || fresh.Snapshot.Balance != 120)
        {
            failures.Add("battle should start at 120 lingshi, got " + fresh.Balance);
        }

        fresh.EnqueuePlace(content.Tower.Id, content.Level.BuildCells[0].Id);
        fresh.EnqueuePlace(content.Tower.Id, content.Level.BuildCells[1].Id);
        if (fresh.Balance != 120 || fresh.TotalBuildSpent != 0)
        {
            failures.Add("rejected build deducted before the tick");
        }

        if (fresh.Snapshot.Note != CombatSimulation.NoteInsufficientLingshi)
        {
            failures.Add("expected 灵石不足 hint, got " + fresh.Snapshot.Note);
        }

        if (fresh.Snapshot.Cells.Count > 1 && (fresh.Snapshot.Cells[1].Queued || fresh.Snapshot.Cells[1].Occupied))
        {
            failures.Add("rejected cell was still queued");
        }

        fresh.Begin();
        fresh.Tick();
        if (fresh.Snapshot.Towers.Count != 1 || fresh.TotalBuildSpent != 100 || fresh.Balance != 20)
        {
            failures.Add("first build should spend 100 and leave 20, towers=" + fresh.Snapshot.Towers.Count + " spent=" + fresh.TotalBuildSpent + " balance=" + fresh.Balance);
        }

        if (fresh.KilledEnemies != 0)
        {
            failures.Add("opening tick should not have killed yet");
        }

        var broke = fresh.Balance;
        fresh.EnqueuePlace(content.Tower.Id, content.Level.BuildCells[2].Id);
        var thirdQueued = fresh.Snapshot.Cells.Count > 2 && fresh.Snapshot.Cells[2].Queued;
        if (broke >= 100 || fresh.Balance != broke || fresh.TotalBuildSpent != 100 || fresh.Snapshot.Towers.Count != 1 || thirdQueued)
        {
            failures.Add("build with balance " + broke + " should be rejected, balance=" + fresh.Balance + " spent=" + fresh.TotalBuildSpent + " towers=" + fresh.Snapshot.Towers.Count);
        }

        if (fresh.Snapshot.Note != CombatSimulation.NoteInsufficientLingshi)
        {
            failures.Add("balance below 100 should hint 灵石不足, got " + fresh.Snapshot.Note);
        }

        var leakTicks = new List<int>();
        var sim = RunAffordableTowers(content, 2, leakTicks);

        if (sim.Phase != BattlePhase.Won || sim.LeakCount != 0)
        {
            failures.Add("economy run did not clear with 0 leaks, phase=" + sim.Phase + " leaks=" + sim.LeakCount + " leakTicks=" + Join(leakTicks) + " balance=" + sim.Balance);
            return;
        }

        if (sim.Snapshot.Towers.Count != 2
            || sim.Snapshot.Towers[0].CellId != "cell_jin_01"
            || sim.Snapshot.Towers[1].CellId != "cell_jin_02"
            || sim.TotalBuildSpent != 200)
        {
            failures.Add("build spend " + sim.TotalBuildSpent + " != 200, towers=" + sim.Snapshot.Towers.Count);
        }

        if (sim.KilledEnemies != 45 || sim.TotalKillRewards != 45 * 8)
        {
            failures.Add("kill rewards kills=" + sim.KilledEnemies + " lingshi=" + sim.TotalKillRewards);
        }

        var clearSum = 0;
        for (var wave = 0; wave < content.Level.Waves.Count; wave++)
        {
            var expected = content.Level.Economy.WaveClearBase + (content.Level.Economy.WaveClearPerWaveIndex * wave);
            clearSum += expected;
            if (sim.WaveClearAmount(wave) != expected)
            {
                failures.Add("wave " + (wave + 1) + " clear " + sim.WaveClearAmount(wave) + " != " + expected);
            }
        }

        if (clearSum != 260 || sim.TotalWaveClearRewards != 260)
        {
            failures.Add("wave clear total " + sim.TotalWaveClearRewards + " formula " + clearSum);
        }

        if (sim.Balance != 540)
        {
            failures.Add("final balance " + sim.Balance + " != 540");
        }

        Notes.Add("economy: start 120, build -200, kill +8 x " + sim.KilledEnemies + ", wave clear " + sim.TotalWaveClearRewards + ", final " + sim.Balance);
    }

    private static void CheckTwoTowers(SliceBattleContent content, List<string> failures)
    {
        var leakTicks = new List<int>();
        var sim = RunAffordableTowers(content, 2, leakTicks);
        if (sim.Phase != BattlePhase.Won || sim.LeakCount != 0)
        {
            failures.Add("2 towers should win with 0 leaks, phase=" + sim.Phase + " leaks=" + sim.LeakCount + " towers=" + sim.Snapshot.Towers.Count + " leakTicks=" + Join(leakTicks) + " balance=" + sim.Balance);
            return;
        }

        if (sim.Snapshot.Towers.Count != 2
            || sim.Snapshot.Towers[0].CellId != "cell_jin_01"
            || sim.Snapshot.Towers[1].CellId != "cell_jin_02"
            || sim.TotalBuildSpent != 200)
        {
            failures.Add("expected towers on cell_jin_01 then cell_jin_02 and spend 200, towers=" + sim.Snapshot.Towers.Count + " spent=" + sim.TotalBuildSpent + " balance=" + sim.Balance);
            return;
        }

        if (!WithinTickTolerance(sim.TickCount, TwoTowerClearTicksBaseline))
        {
            failures.Add("2 tower clear ticks " + sim.TickCount + " outside ±5% of calibrated " + TwoTowerClearTicksBaseline + ", leaks=" + sim.LeakCount);
        }

        if (sim.Balance != 540)
        {
            failures.Add("2 tower final balance " + sim.Balance + " != 540");
            return;
        }

        Notes.Add("two towers: 01 then 02, spend 200, leaks=0, ticks=" + sim.TickCount + " (±5% of " + TwoTowerClearTicksBaseline + ", designTicks=1932, delta=" + (sim.TickCount - 1932) + "), final balance=" + sim.Balance);
    }

    private static string NextBuildCell(CombatSimulation sim, string[] order)
    {
        var cells = sim.Snapshot.Cells;
        for (var i = 0; i < order.Length; i++)
        {
            for (var c = 0; c < cells.Count; c++)
            {
                if (cells[c].Id != order[i])
                {
                    continue;
                }

                if (!cells[c].Occupied && !cells[c].Queued)
                {
                    return order[i];
                }

                break;
            }
        }

        return null;
    }

    private static void CheckThreeTowers(SliceBattleContent content, List<string> failures)
    {
        var sim = StartPlacedOn(content, ThreeTowerBuildOrder[0]);
        var triedFourth = false;
        var guard = 0;
        var leakTicks = new List<int>();
        var previousLeaks = 0;
        while (sim.Phase == BattlePhase.Running && guard++ < 20000)
        {
            sim.Tick();
            if (sim.LeakCount > previousLeaks)
            {
                leakTicks.Add(sim.TickCount);
                previousLeaks = sim.LeakCount;
            }

            if (sim.Phase != BattlePhase.Running)
            {
                break;
            }

            if (sim.Snapshot.Towers.Count >= 3)
            {
                if (!triedFourth)
                {
                    var balance = sim.Balance;
                    var spent = sim.TotalBuildSpent;
                    sim.EnqueuePlace(content.Tower.Id, ThreeTowerBuildOrder[0]);
                    triedFourth = true;
                    if (sim.Balance != balance || sim.TotalBuildSpent != spent || sim.Snapshot.Towers.Count != 3)
                    {
                        failures.Add("occupied cell still changed the battle");
                    }

                    if (sim.Snapshot.Note != CombatSimulation.NoteCellTaken)
                    {
                        failures.Add("expected occupied-cell hint, got " + sim.Snapshot.Note);
                    }
                }

                continue;
            }

            if (sim.Balance < content.Tower.BuildCost)
            {
                continue;
            }

            var free = NextBuildCell(sim, ThreeTowerBuildOrder);
            if (free != null)
            {
                sim.EnqueuePlace(content.Tower.Id, free);
            }
        }

        if (sim.Phase != BattlePhase.Won || sim.LeakCount != 0)
        {
            failures.Add("3 towers should still win with 0 leaks, phase=" + sim.Phase + " leaks=" + sim.LeakCount + " towers=" + sim.Snapshot.Towers.Count + " leakTicks=" + Join(leakTicks));
            return;
        }

        if (sim.Snapshot.Towers.Count != 3 || sim.TotalBuildSpent != 300)
        {
            failures.Add("expected 3 towers and spend 300, towers=" + sim.Snapshot.Towers.Count + " spent=" + sim.TotalBuildSpent + " balance=" + sim.Balance);
            return;
        }

        for (var i = 0; i < ThreeTowerBuildOrder.Length; i++)
        {
            if (sim.Snapshot.Towers[i].CellId != ThreeTowerBuildOrder[i])
            {
                failures.Add("3 towers were not built cell_jin_01 then cell_jin_02 then cell_jin_03, got "
                    + sim.Snapshot.Towers[0].CellId + " "
                    + sim.Snapshot.Towers[1].CellId + " "
                    + sim.Snapshot.Towers[2].CellId);
                return;
            }
        }

        if (!WithinTickTolerance(sim.TickCount, ThreeTowerClearTicksBaseline))
        {
            failures.Add("3 tower clear ticks " + sim.TickCount + " outside ±5% of calibrated " + ThreeTowerClearTicksBaseline + ", leaks=" + sim.LeakCount);
        }

        if (sim.Balance != 440)
        {
            failures.Add("3 tower final balance " + sim.Balance + " != 440");
            return;
        }

        Notes.Add("three towers: 01 then 02 then 03, spend 300, leaks=0, ticks=" + sim.TickCount + " (±5% of " + ThreeTowerClearTicksBaseline + "), final balance=" + sim.Balance);
    }

    private static void CheckWaveClearPaysWhenLeaked(SliceBattleContent content, List<string> failures)
    {
        var original = content.Level.LoseLeakCount;
        content.Level.LoseLeakCount = 45;
        try
        {
            CombatSimulation sim;
            string error;
            if (!CombatSimulation.TryCreate(content, out sim, out error))
            {
                failures.Add(error);
                return;
            }

            sim.Begin();
            var guard = 0;
            while (sim.Phase == BattlePhase.Running && sim.WaveClearAmount(0) == 0 && guard++ < 20000)
            {
                sim.Tick();
            }

            if (sim.WaveClearAmount(0) != 15)
            {
                failures.Add("fully leaked wave 1 should still pay 15, got " + sim.WaveClearAmount(0) + " leaks=" + sim.LeakCount + " tick=" + sim.TickCount);
                return;
            }

            if (sim.KilledEnemies != 0 || sim.TotalKillRewards != 0)
            {
                failures.Add("leaked enemies granted kill reward");
            }

            if (sim.LeakCount != 4 || sim.Balance != 135)
            {
                failures.Add("wave 1 leak clear unexpected leaks=" + sim.LeakCount + " balance=" + sim.Balance);
                return;
            }

            Notes.Add("wave clear: 4 leaked enemies pay 0 kill reward and still pay wave-1 bonus 15");
        }
        finally
        {
            content.Level.LoseLeakCount = original;
        }
    }

    private static void CheckBattleBackground(string root, SliceBattleContent content, List<string> failures)
    {
        if (content.Level.Background != "bg_jizhou01_battle")
        {
            failures.Add("level background is not bg_jizhou01_battle");
        }

        var levelText = File.ReadAllText(Path.Combine(root, "content", "levels", "level_jizhou_01.json"));
        if (levelText.IndexOf("背景与 path_jizhou_01 绑定，改航点必须同步改图", StringComparison.Ordinal) < 0)
        {
            failures.Add("level notes do not bind the background to path_jizhou_01");
        }

        var png = Path.Combine(root, "Assets", "Game", "Art", "Backgrounds", "bg_jizhou01_battle.png");
        var metaPath = png + ".meta";
        if (!File.Exists(png) || !File.Exists(metaPath))
        {
            failures.Add("battle background sprite or meta is missing");
            return;
        }

        var header = File.ReadAllBytes(png);
        if (header.Length < 24
            || header[16] != 0
            || header[17] != 0
            || header[18] != 7
            || header[19] != 128
            || header[20] != 0
            || header[21] != 0
            || header[22] != 4
            || header[23] != 56)
        {
            failures.Add("battle background is not a 1920x1080 PNG");
        }

        var meta = File.ReadAllText(metaPath);
        if (meta.IndexOf("spritePixelsToUnits: 120", StringComparison.Ordinal) < 0
            || meta.IndexOf("enableMipMap: 0", StringComparison.Ordinal) < 0
            || meta.IndexOf("filterMode: 1", StringComparison.Ordinal) < 0
            || meta.IndexOf("maxTextureSize: 2048", StringComparison.Ordinal) < 0
            || meta.IndexOf("alphaIsTransparency: 0", StringComparison.Ordinal) < 0)
        {
            failures.Add("battle background import settings drifted from PPU 120 / no mipmap / bilinear / max 2048");
        }

        if (meta.IndexOf("buildTarget: Android", StringComparison.Ordinal) < 0
            || meta.IndexOf("buildTarget: iPhone", StringComparison.Ordinal) < 0
            || meta.IndexOf("textureFormat: 50", StringComparison.Ordinal) < 0)
        {
            failures.Add("battle background is missing iOS/Android ASTC 6x6 override");
        }
    }

    private static void CheckBattleArt(string root, List<string> failures)
    {
        var bleed = Path.Combine(root, "Assets", "Game", "Art", "Backgrounds", "bg_jizhou01_battle_bleed.png");
        var bleedMetaPath = bleed + ".meta";
        if (!File.Exists(bleed) || !File.Exists(bleedMetaPath))
        {
            failures.Add("battle bleed sprite or meta is missing");
            return;
        }

        var header = File.ReadAllBytes(bleed);
        if (header.Length < 24
            || header[16] != 0
            || header[17] != 0
            || header[18] != 9
            || header[19] != 0xD8
            || header[20] != 0
            || header[21] != 0
            || header[22] != 5
            || header[23] != 0xA0)
        {
            failures.Add("battle bleed is not a 2520x1440 PNG");
        }

        var bleedMeta = File.ReadAllText(bleedMetaPath);
        if (bleedMeta.IndexOf("spritePixelsToUnits: 120", StringComparison.Ordinal) < 0
            || bleedMeta.IndexOf("enableMipMap: 0", StringComparison.Ordinal) < 0
            || bleedMeta.IndexOf("filterMode: 1", StringComparison.Ordinal) < 0
            || bleedMeta.IndexOf("maxTextureSize: 4096", StringComparison.Ordinal) < 0
            || bleedMeta.IndexOf("alphaIsTransparency: 0", StringComparison.Ordinal) < 0
            || bleedMeta.IndexOf("width: 2520", StringComparison.Ordinal) < 0
            || bleedMeta.IndexOf("height: 1440", StringComparison.Ordinal) < 0)
        {
            failures.Add("battle bleed import settings drifted from PPU 120 / 2520x1440 / max 4096");
        }

        if (bleedMeta.IndexOf("textureFormat: 50", StringComparison.Ordinal) < 0)
        {
            failures.Add("battle bleed is missing ASTC 6x6 override");
        }

        CheckBattleSceneSprites(root, failures);

        ExpectArtMeta(root, "tower_jin_body.png", new[]
        {
            "spritePixelsToUnits: 160",
            "alphaIsTransparency: 1",
            "spriteMode: 1",
            "textureFormat: 50",
            "alignment: 9",
            "spritePivot: {x: 0.5, y: 0.227}",
            "pivot: {x: 0.5, y: 0.227}",
        }, failures);
        ExpectArtMeta(root, "tower_jin_fx.png", new[] { "spritePixelsToUnits: 160", "spriteMode: 2", "name: fx_0", "name: fx_3", "textureFormat: 50" }, failures);
        ExpectArtMeta(root, "enemy_dangkang_walk.png", new[] { "spritePixelsToUnits: 160", "spriteMode: 2", "name: walk_0", "name: walk_7", "alphaIsTransparency: 1" }, failures);
        ExpectArtMeta(root, "ding_bronze.png", new[] { "spritePixelsToUnits: 170", "alphaIsTransparency: 1" }, failures);
        ExpectArtMeta(root, "buildslot_states.png", new[] { "spritePixelsToUnits: 200", "spriteMode: 2", "name: slot_normal", "name: slot_selected", "name: slot_disabled" }, failures);
        ExpectArtMeta(root, "hud_lingshi.png", new[] { "spritePixelsToUnits: 160", "alphaIsTransparency: 1" }, failures);
        ExpectArtMeta(root, "hud_heart.png", new[] { "spritePixelsToUnits: 160" }, failures);
        ExpectArtMeta(root, "hud_wave.png", new[] { "spritePixelsToUnits: 160" }, failures);
        ExpectArtMeta(root, "enemy_dangkang_hit_flash_white.png", new[] { "spritePixelsToUnits: 160" }, failures);
        ExpectArtMeta(root, "enemy_dangkang_hit_flash_red.png", new[] { "spritePixelsToUnits: 160" }, failures);
        ExpectArtMeta(root, "enemy_dangkang_death.png", new[] { "spritePixelsToUnits: 160" }, failures);
    }

    private static void ExpectArtMeta(string root, string fileName, string[] needles, List<string> failures)
    {
        var path = Path.Combine(root, "Assets", "Game", "Resources", "BattleArt", fileName);
        if (!File.Exists(path) || !File.Exists(path + ".meta"))
        {
            failures.Add("missing battle art " + fileName);
            return;
        }

        var meta = File.ReadAllText(path + ".meta");
        for (var i = 0; i < needles.Length; i++)
        {
            if (meta.IndexOf(needles[i], StringComparison.Ordinal) < 0)
            {
                failures.Add(fileName + " meta missing " + needles[i]);
            }
        }
    }

    /// <summary>
    /// 按对象块断言 BattleBackground / BattleBackgroundBleed，而不是在整份场景里搜 sortingOrder。
    /// </summary>
    private static void CheckBattleSceneSprites(string root, List<string> failures)
    {
        var scenePath = Path.Combine(root, "Assets", "Game", "Scenes", "Battle.unity");
        if (!File.Exists(scenePath))
        {
            failures.Add("battle scene is missing");
            return;
        }

        var scene = File.ReadAllText(scenePath);
        var backgroundGuid = ReadMetaGuid(Path.Combine(root, "Assets", "Game", "Art", "Backgrounds", "bg_jizhou01_battle.png.meta"));
        var bleedGuid = ReadMetaGuid(Path.Combine(root, "Assets", "Game", "Art", "Backgrounds", "bg_jizhou01_battle_bleed.png.meta"));
        ExpectSceneSprite(scene, "BattleBackground", backgroundGuid, -100, "m_Size: {x: 16, y: 9}", failures);
        ExpectSceneSprite(scene, "BattleBackgroundBleed", bleedGuid, -110, "m_Size: {x: 21, y: 12}", failures);
    }

    private static void ExpectSceneSprite(string scene, string objectName, string spriteGuid, int sortingOrder, string sizeLine, List<string> failures)
    {
        string gameObjectDoc;
        if (!TrySliceNamedObject(scene, objectName, out gameObjectDoc))
        {
            failures.Add("battle scene is missing " + objectName);
            return;
        }

        string fileId;
        if (!TryHeaderFileId(gameObjectDoc, out fileId))
        {
            failures.Add(objectName + " has no fileID");
            return;
        }

        var componentIds = ReadComponentFileIds(gameObjectDoc);
        string transformDoc = null;
        string rendererDoc = null;
        for (var i = 0; i < componentIds.Count; i++)
        {
            string doc;
            if (!TrySliceDocument(scene, "&" + componentIds[i], out doc))
            {
                continue;
            }

            if (transformDoc == null && doc.IndexOf("m_LocalScale:", StringComparison.Ordinal) >= 0)
            {
                transformDoc = doc;
            }

            if (rendererDoc == null && doc.IndexOf("m_Sprite:", StringComparison.Ordinal) >= 0)
            {
                rendererDoc = doc;
            }
        }

        if (transformDoc == null || rendererDoc == null)
        {
            failures.Add(objectName + " is missing Transform or SpriteRenderer");
            return;
        }

        var scale = LineContaining(transformDoc, "m_LocalScale:");
        if (scale != "m_LocalScale: {x: 1, y: 1, z: 1}")
        {
            failures.Add(objectName + " local scale is not 1");
        }

        var order = LineContaining(rendererDoc, "m_SortingOrder:");
        if (order != "m_SortingOrder: " + sortingOrder)
        {
            failures.Add(objectName + " sorting order is not " + sortingOrder);
        }

        var sprite = LineContaining(rendererDoc, "m_Sprite:");
        if (string.IsNullOrEmpty(spriteGuid) || sprite == null || sprite.IndexOf("guid: " + spriteGuid, StringComparison.Ordinal) < 0)
        {
            failures.Add(objectName + " sprite guid is not " + (spriteGuid ?? "(missing meta guid)"));
        }

        var size = LineContaining(rendererDoc, "m_Size:");
        if (size != sizeLine)
        {
            failures.Add(objectName + " sprite size is not " + sizeLine);
        }
    }

    private static string ReadMetaGuid(string metaPath)
    {
        if (!File.Exists(metaPath))
        {
            return null;
        }

        var lines = File.ReadAllLines(metaPath);
        for (var i = 0; i < lines.Length; i++)
        {
            var line = lines[i].Trim();
            if (line.StartsWith("guid:", StringComparison.Ordinal))
            {
                return line.Substring("guid:".Length).Trim();
            }
        }

        return null;
    }

    private static bool TrySliceNamedObject(string scene, string objectName, out string document)
    {
        var needle = "m_Name: " + objectName;
        var index = 0;
        while (index < scene.Length)
        {
            index = scene.IndexOf(needle, index, StringComparison.Ordinal);
            if (index < 0)
            {
                document = null;
                return false;
            }

            var after = index + needle.Length;
            if (after >= scene.Length || scene[after] == '\n' || scene[after] == '\r')
            {
                return TrySliceAround(scene, index, out document);
            }

            index = after;
        }

        document = null;
        return false;
    }

    private static bool TrySliceDocument(string scene, string headerToken, out string document)
    {
        var needle = headerToken + "\n";
        var index = scene.IndexOf(needle, StringComparison.Ordinal);
        if (index < 0)
        {
            needle = headerToken + "\r";
            index = scene.IndexOf(needle, StringComparison.Ordinal);
        }

        if (index < 0)
        {
            document = null;
            return false;
        }

        return TrySliceAround(scene, index, out document);
    }

    private static bool TrySliceAround(string scene, int index, out string document)
    {
        var start = scene.LastIndexOf("\n--- ", index, StringComparison.Ordinal);
        if (start < 0)
        {
            start = 0;
        }
        else
        {
            start += 1;
        }

        var end = scene.IndexOf("\n--- ", index, StringComparison.Ordinal);
        if (end < 0)
        {
            end = scene.Length;
        }

        document = scene.Substring(start, end - start);
        return true;
    }

    private static bool TryHeaderFileId(string document, out string fileId)
    {
        fileId = null;
        var marker = document.IndexOf("&", StringComparison.Ordinal);
        if (marker < 0)
        {
            return false;
        }

        var start = marker + 1;
        var end = start;
        while (end < document.Length && document[end] >= '0' && document[end] <= '9')
        {
            end++;
        }

        if (end == start)
        {
            return false;
        }

        fileId = document.Substring(start, end - start);
        return true;
    }

    private static List<string> ReadComponentFileIds(string document)
    {
        var ids = new List<string>();
        var marker = "component: {fileID: ";
        var index = 0;
        while (index < document.Length)
        {
            index = document.IndexOf(marker, index, StringComparison.Ordinal);
            if (index < 0)
            {
                break;
            }

            var start = index + marker.Length;
            var end = start;
            while (end < document.Length && document[end] >= '0' && document[end] <= '9')
            {
                end++;
            }

            if (end > start)
            {
                ids.Add(document.Substring(start, end - start));
            }

            index = end;
        }

        return ids;
    }

    private static string LineContaining(string document, string token)
    {
        var index = document.IndexOf(token, StringComparison.Ordinal);
        if (index < 0)
        {
            return null;
        }

        var start = document.LastIndexOf('\n', index);
        start = start < 0 ? 0 : start + 1;
        var end = document.IndexOf('\n', index);
        if (end < 0)
        {
            end = document.Length;
        }

        if (end > start && document[end - 1] == '\r')
        {
            end--;
        }

        return document.Substring(start, end - start).Trim();
    }

    private static void CheckSpace(string root, List<string> failures)
    {
        var levelPath = Path.Combine(root, "content", "levels", "level_jizhou_01.json");
        var level = File.ReadAllText(levelPath);
        RejectLevel(level.Replace("\"x\": 1.470", "\"x\": 1.9"), "x above 1.778", failures);
        RejectLevel(level.Replace("\"y\": 0.140", "\"y\": 1.2"), "y above 1", failures);
        RejectLevel(level.Replace("\"x\": 0.270", "\"x\": -0.01"), "negative x", failures);
        RejectLevel(level.Replace("\"space\": \"height_units_16x9\"", "\"space\": \"normalized_playfield\""), "formal points are outside normalized_playfield", failures);
        RejectLevel(level.Replace("\"space\": \"height_units_16x9\"", "\"space\": \"world_units\""), "unknown space", failures);

        LevelDefinition parsed;
        string error;
        if (!SliceTables.TryParseLevel(LegacyNormalizedLevel(), out parsed, out error))
        {
            failures.Add("normalized_playfield inside [0,1] should still load: " + error);
        }
        else if (parsed.Space != SliceRules.SpaceNormalizedPlayfield)
        {
            failures.Add("legacy space was rewritten");
        }

        if (SliceTables.TryParseLevel(LegacyNormalizedLevel().Replace("\"x\":1", "\"x\":1.001"), out parsed, out error))
        {
            failures.Add("normalized_playfield should reject x=1.001");
        }

        var onEdge = level.Replace("\"x\": 1.530", "\"x\": 1.778").Replace("\"y\": 0.230", "\"y\": 1");
        if (!SliceTables.TryParseLevel(onEdge, out parsed, out error))
        {
            failures.Add("height_units_16x9 should accept the closed edge 1.778,1: " + error);
        }

    }

    private static void RejectLevel(string json, string label, List<string> failures)
    {
        LevelDefinition parsed;
        string error;
        if (SliceTables.TryParseLevel(json, out parsed, out error))
        {
            failures.Add(label + " was accepted");
        }
    }

    private static string LegacyNormalizedLevel()
    {
        return "{"
            + "\"schema\":\"shdg.level.waves\",\"schemaVersion\":0,\"id\":\"level_jizhou_01\","
            + "\"displayName\":\"legacy\",\"placeholder\":false,\"slice\":\"jizhou_01_formal\","
            + "\"pathId\":\"path_jizhou_01\",\"space\":\"normalized_playfield\","
            + "\"waypoints\":[{\"id\":\"a\",\"x\":0,\"y\":0},{\"id\":\"b\",\"x\":1,\"y\":1}],"
            + "\"buildCells\":[{\"id\":\"cell_jin_01\",\"x\":0.5,\"y\":0.5}],"
            + "\"economy\":{\"currencyId\":\"lingshi\",\"startingAmount\":120,\"waveClearBase\":15,\"waveClearPerWaveIndex\":5},"
            + "\"waves\":[{\"id\":\"wave_01\",\"spawns\":[{\"enemyId\":\"enemy_dangkang\",\"count\":1,\"intervalTicks\":48}]}],"
            + "\"outcome\":{\"win\":\"all_waves_cleared\",\"lose\":\"leak_count\",\"loseLeakCount\":3}"
            + "}";
    }

    private static bool ExpectPoint(List<WaypointDefinition> points, int index, string id, double x, double y, List<string> failures)
    {
        if (points.Count <= index)
        {
            failures.Add("missing waypoint " + id);
            return false;
        }

        var point = points[index];
        if (point.Id != id || Math.Abs(point.X - x) > 1e-9 || Math.Abs(point.Y - y) > 1e-9)
        {
            failures.Add("waypoint " + index + " is " + point.Id + " (" + point.X + "," + point.Y + "), expected " + id + " (" + x + "," + y + ")");
            return false;
        }

        return true;
    }

    private static bool ExpectCell(List<BuildCellDefinition> cells, int index, string id, double x, double y, List<string> failures)
    {
        if (cells.Count <= index)
        {
            failures.Add("missing build cell " + id);
            return false;
        }

        var cell = cells[index];
        if (cell.Id != id || Math.Abs(cell.X - x) > 1e-9 || Math.Abs(cell.Y - y) > 1e-9)
        {
            failures.Add("cell " + index + " is " + cell.Id + " (" + cell.X + "," + cell.Y + "), expected " + id + " (" + x + "," + y + ")");
            return false;
        }

        return true;
    }

    private static bool WithinTickTolerance(int actual, int baseline)
    {
        var limit = baseline * TickTolerance;
        return Math.Abs(actual - baseline) <= limit;
    }

    private static string Join(List<int> values)
    {
        if (values.Count == 0)
        {
            return "-";
        }

        var text = values[0].ToString();
        for (var i = 1; i < values.Count; i++)
        {
            text += "," + values[i];
        }

        return text;
    }

    private static void CheckLevelProgressRoundTrip(List<string> failures)
    {
        string updated;
        string error;
        bool kept;
        if (!LevelResultRecorder.TryUpsert("{}", "level_jizhou_01", true, 0, out updated, out error, out kept))
        {
            failures.Add("level progress: " + error);
            return;
        }

        var profile = PlayerProfile.CreateEmpty("dev.guest");
        profile.LevelProgressJson = updated;
        string json;
        if (!PlayerProfileJson.TryWrite(profile, out json, out error))
        {
            failures.Add("profile write: " + error);
            return;
        }

        PlayerProfile read;
        if (!PlayerProfileJson.TryRead(json, out read, out error))
        {
            failures.Add("profile read: " + error);
            return;
        }

        string again;
        if (!LevelResultRecorder.TryUpsert(read.LevelProgressJson, "level_jizhou_01", false, 3, out again, out error, out kept) || !kept)
        {
            failures.Add("a later loss overwrote the win");
            return;
        }

        if (!LevelResultRecorder.TryUpsert(read.LevelProgressJson, "level_other", false, 1, out again, out error, out kept))
        {
            failures.Add("second level: " + error);
            return;
        }

        if (again.IndexOf("level_jizhou_01", StringComparison.Ordinal) < 0 || again.IndexOf("level_other", StringComparison.Ordinal) < 0)
        {
            failures.Add("level progress dropped an entry: " + again);
        }
    }

    private static string FindRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            if (File.Exists(Path.Combine(dir.FullName, "docs", "ARCHITECTURE.md")))
            {
                return dir.FullName;
            }

            dir = dir.Parent;
        }

        return Directory.GetCurrentDirectory();
    }
}
