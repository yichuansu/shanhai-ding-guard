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
            CheckSpace(root, failures);
            CheckHpMultiplierDefault(root, failures);
            CheckWin(content, failures);
            CheckLose(content, failures);
            CheckSpeedDoesNotChangeDamageOrTickCount(content, failures);
            CheckTickBeforeBeginDoesNothing(content, failures);
            CheckEconomy(content, failures);
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
    /// tick 基线取 m1-slice-check 实测，断言为该值的 ±5%。灵石和漏怪数仍是精确值。
    /// 数值策划预期是 1 塔约 1786 tick、无塔约 944 tick；实测 1815（+29，+1.6%）与 947（+3，+0.3%）。
    /// 3 塔通关 tick 与 1 塔同为 1815，同样 ±5%，漏怪必须为 0。终局灵石只做精确回归。
    /// </summary>
    private const int OneTowerClearTicksBaseline = 1815;

    private const int NoTowerLoseTicksBaseline = 947;

    private const int ThreeTowerClearTicksBaseline = 1815;

    private const double TickTolerance = 0.05;

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

        if (!ExpectPoint(content.Level.Waypoints, 0, "wp_spawn", 1.46, 0.85, failures)
            || !ExpectPoint(content.Level.Waypoints, 1, "wp_lane1_west", 0.32, 0.85, failures)
            || !ExpectPoint(content.Level.Waypoints, 2, "wp_lane2_west", 0.32, 0.62, failures)
            || !ExpectPoint(content.Level.Waypoints, 3, "wp_lane2_east", 1.42, 0.62, failures)
            || !ExpectPoint(content.Level.Waypoints, 4, "wp_lane3_east", 1.42, 0.44, failures)
            || !ExpectPoint(content.Level.Waypoints, 5, "wp_lane3_west", 0.36, 0.44, failures)
            || !ExpectPoint(content.Level.Waypoints, 6, "wp_lane4_west", 0.36, 0.23, failures)
            || !ExpectPoint(content.Level.Waypoints, 7, "wp_ding", 1.53, 0.23, failures))
        {
            return;
        }

        if (content.Level.Waypoints.Count != 8)
        {
            failures.Add("expected 8 waypoints, got " + content.Level.Waypoints.Count);
        }

        if (!ExpectCell(content.Level.BuildCells, 0, "cell_jin_01", 0.90, 0.735, failures)
            || !ExpectCell(content.Level.BuildCells, 1, "cell_jin_02", 1.20, 0.53, failures)
            || !ExpectCell(content.Level.BuildCells, 2, "cell_jin_03", 0.60, 0.335, failures))
        {
            return;
        }

        var path = new ShanhaiDingGuard.Gameplay.Path.PathCurve(content.Level.Waypoints);
        if (Math.Abs(path.Length - 5.09) > 1e-9)
        {
            failures.Add("path length " + path.Length.ToString("0.0000") + " is not 5.09");
        }
        else
        {
            Notes.Add("path length=" + path.Length.ToString("0.0000"));
        }

        if (content.Tower.BuildCost != 100)
        {
            failures.Add("build cost drifted from 100");
        }

        if (content.Enemy.MaxHp != 40 || content.Enemy.RewardAmount != 8 || content.Enemy.RewardCurrencyId != "lingshi")
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

        if (CombatSimulation.ScaleMaxHp(40, 1.1) != 44 || CombatSimulation.ScaleMaxHp(40, 1.0) != 40)
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

    private static void CheckWin(SliceBattleContent content, List<string> failures)
    {
        var sim = StartPlaced(content);
        var hits = new List<int>();
        var leakTicks = new List<int>();
        var saw40 = false;
        var saw44 = false;
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
                if (enemies[i].MaxHp == 40)
                {
                    saw40 = true;
                }

                if (enemies[i].MaxHp == 44)
                {
                    saw44 = true;
                }
            }
        }

        if (sim.Phase != BattlePhase.Won)
        {
            failures.Add("placed tower should win, phase=" + sim.Phase + " tick=" + sim.TickCount + " leaks=" + sim.LeakCount + " alive=" + sim.Snapshot.Enemies.Count + " leakTicks=" + Join(leakTicks) + " balance=" + sim.Balance);
            return;
        }

        Notes.Add("win: 1 tower, leaks=0, ticks=" + sim.TickCount + " (" + (sim.TickCount * SimClock.TickSeconds).ToString("0.0") + "s at 1x), balance=" + sim.Balance + ", designTicks=1786, delta=" + (sim.TickCount - 1786));

        if (sim.LeakCount != 0)
        {
            failures.Add("win should have zero leaks");
        }

        if (sim.Balance != 640)
        {
            failures.Add("1 tower final balance " + sim.Balance + " != 640");
        }

        if (!WithinTickTolerance(sim.TickCount, OneTowerClearTicksBaseline))
        {
            failures.Add("1 tower clear ticks " + sim.TickCount + " outside ±5% of calibrated " + OneTowerClearTicksBaseline);
        }

        if (hits.Count == 0)
        {
            failures.Add("tower never fired");
        }

        for (var i = 0; i < hits.Count; i++)
        {
            if (hits[i] != content.Tower.Damage || hits[i] != 10)
            {
                failures.Add("hit damage " + hits[i] + " != table damage " + content.Tower.Damage);
                break;
            }
        }

        if (!saw40 || !saw44)
        {
            failures.Add("expected spawned maxHp 40 and wave-8 maxHp 44, saw40=" + saw40 + " saw44=" + saw44);
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
            Notes.Add("lose: no tower, leaks=3 at tick " + sim.TickCount + ", designTicks=944, delta=" + (sim.TickCount - 944));
            if (!WithinTickTolerance(sim.TickCount, NoTowerLoseTicksBaseline))
            {
                failures.Add("no-tower lose ticks " + sim.TickCount + " outside ±5% of calibrated " + NoTowerLoseTicksBaseline);
            }
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
        int frames2;
        int ticks2;
        if (!RunClock(content, 1, out frames1, out ticks1, failures) || !RunClock(content, 2, out frames2, out ticks2, failures))
        {
            return;
        }

        if (ticks1 != ticks2)
        {
            failures.Add("2x changed the sim tick count " + ticks1 + " vs " + ticks2);
            return;
        }

        if (!(frames2 < frames1 * 0.6) || !(frames2 > frames1 * 0.4))
        {
            failures.Add("2x wall frames " + frames2 + " were not about half of 1x " + frames1);
            return;
        }

        Notes.Add("speed: hit damage stays 10, ticks=" + ticks1 + ", 1x frames=" + frames1 + ", 2x frames=" + frames2);
    }

    private static bool RunClock(SliceBattleContent content, int speed, out int frames, out int ticks, List<string> failures)
    {
        frames = 0;
        ticks = 0;
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
        if (sim.Phase != BattlePhase.Won)
        {
            failures.Add("speed " + speed + " did not win");
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
        CombatSimulation sim;
        string error;
        if (!CombatSimulation.TryCreate(content, out sim, out error))
        {
            throw new InvalidOperationException(error);
        }

        sim.EnqueuePlace(content.Tower.Id, content.Level.BuildCells[0].Id);
        sim.Begin();
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

        var sim = StartPlaced(content);
        var leakTicks = new List<int>();
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
        }

        if (sim.Phase != BattlePhase.Won || sim.LeakCount != 0)
        {
            failures.Add("economy run did not clear with 0 leaks, phase=" + sim.Phase + " leaks=" + sim.LeakCount + " leakTicks=" + Join(leakTicks) + " balance=" + sim.Balance);
            return;
        }

        if (sim.TotalBuildSpent != 100)
        {
            failures.Add("build spend " + sim.TotalBuildSpent + " != 100");
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

        if (sim.Balance != 640)
        {
            failures.Add("final balance " + sim.Balance + " != 640");
        }

        Notes.Add("economy: start 120, build -100, kill +8 x " + sim.KilledEnemies + ", wave clear " + sim.TotalWaveClearRewards + ", final " + sim.Balance);
    }

    private static void CheckThreeTowers(SliceBattleContent content, List<string> failures)
    {
        var sim = StartPlaced(content);
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
                    sim.EnqueuePlace(content.Tower.Id, content.Level.BuildCells[0].Id);
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

        if (!WithinTickTolerance(sim.TickCount, ThreeTowerClearTicksBaseline))
        {
            failures.Add("3 tower clear ticks " + sim.TickCount + " outside ±5% of calibrated " + ThreeTowerClearTicksBaseline + ", leaks=" + sim.LeakCount);
        }

        if (sim.Balance != 440)
        {
            failures.Add("3 tower final balance " + sim.Balance + " != 440");
            return;
        }

        Notes.Add("three towers: spend 300, leaks=0, ticks=" + sim.TickCount + " (±5% of " + ThreeTowerClearTicksBaseline + "), final balance=" + sim.Balance);
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

    private static void CheckSpace(string root, List<string> failures)
    {
        var levelPath = Path.Combine(root, "content", "levels", "level_jizhou_01.json");
        var level = File.ReadAllText(levelPath);
        RejectLevel(level.Replace("\"x\": 1.46", "\"x\": 1.9"), "x above 1.778", failures);
        RejectLevel(level.Replace("\"y\": 0.23", "\"y\": 1.2"), "y above 1", failures);
        RejectLevel(level.Replace("\"x\": 0.32", "\"x\": -0.01"), "negative x", failures);
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

        var onEdge = level.Replace("\"x\": 1.53", "\"x\": 1.778").Replace("\"y\": 0.23", "\"y\": 1");
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
