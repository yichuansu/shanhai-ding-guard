using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using ShanhaiDingGuard.Content;
using ShanhaiDingGuard.Gameplay.CombatSimulation;

/// <summary>
/// 剑阵真弹道实验。不改 JSON，不改 m1-slice-check 基线。
/// 正式索敌是选项 R；R 关只作对照。弹速不低于 0.04 高度单位/tick。
/// </summary>
internal static class Program
{
    private const int GuardTicks = 20000;

    private static int Main()
    {
        var failures = new List<string>();
        var content = LoadSlice(failures);
        if (content == null)
        {
            return Fail(failures);
        }

        var range = content.Tower.Range;
        var medium = range / 2.0;
        var fast = medium / 2.0;
        var slow = medium / 3.0;
        var raised = false;
        if (fast < CombatSimulation.MinSwordSpeedPerTick)
        {
            fast = CombatSimulation.MinSwordSpeedPerTick;
            raised = true;
        }

        if (slow < CombatSimulation.MinSwordSpeedPerTick)
        {
            slow = CombatSimulation.MinSwordSpeedPerTick;
            raised = true;
        }

        Console.WriteLine("range=" + F(range) + " medium=" + F(medium) + " fast=" + F(fast) + " slow=" + F(slow) + " raised=" + raised + " path=" + F(new PathLength(content).Value));
        ProbeFloor(failures);
        ProbeFlight(range, fast, ExpectedHitTick(medium, fast), failures);
        ProbeFlight(range, slow, ExpectedHitTick(medium, slow), failures);
        ProbeOverkill(range, fast, failures);
        ProbeWaste(range, fast, false, failures);
        ProbeWaste(range, fast, true, failures);
        ProbeHoming(fast, failures);
        if (failures.Count > 0)
        {
            return Fail(failures);
        }

        Console.WriteLine("PROBES passed");
        var instant = new Dictionary<string, RunResult>();
        foreach (var scenario in Scenarios)
        {
            var result = Run(content, null, scenario);
            instant[scenario] = result;
            AssertInstant(result, failures);
        }

        if (failures.Count > 0)
        {
            PrintRuns("instant", new List<RunResult>(instant.Values));
            return Fail(failures);
        }

        Console.WriteLine("INSTANT baselines matched, including 2nd tower tick " + instant["t2"].Place2 + " and 3rd tower tick " + instant["t3"].Place3);
        var groups = new[]
        {
            new SwordSetup("fast-R", fast, true),
            new SwordSetup("fast-noR", fast, false),
            new SwordSetup("slow-R", slow, true),
            new SwordSetup("slow-noR", slow, false),
            new SwordSetup("align-0.04-R", 0.04, true),
            new SwordSetup("align-0.08-R", 0.08, true),
        };

        var all = new List<RunResult>();
        foreach (var setup in groups)
        {
            foreach (var scenario in Scenarios)
            {
                var direct = Run(content, setup, scenario);
                direct.Config = setup.Name;
                all.Add(direct);
                CheckDeterminism(content, setup, scenario, direct, failures);
            }
        }

        PrintRuns("results", all);
        PrintComparison(all, instant);
        PrintGoals(all);
        return failures.Count == 0 ? 0 : Fail(failures);
    }

    private static readonly string[] Scenarios = { "none", "01", "02", "03", "t2", "t3" };

    private static void AssertInstant(RunResult result, List<string> failures)
    {
        Expect(result, "none", BattlePhase.Lost, 946, 3, 120, failures);
        Expect(result, "01", BattlePhase.Lost, 1806, 3, 321, failures);
        Expect(result, "02", BattlePhase.Lost, 2135, 3, 449, failures);
        Expect(result, "03", BattlePhase.Lost, 1775, 3, 313, failures);
        Expect(result, "t2", BattlePhase.Won, 1977, 0, 540, failures);
        Expect(result, "t3", BattlePhase.Won, 1977, 0, 440, failures);
        if (result.Scenario == "t2" && (result.Killed != 45 || result.Place2 != 478))
        {
            failures.Add("instant t2 kills/place2 " + result.Killed + "/" + result.Place2 + " expected 45/478");
        }

        if (result.Scenario == "t3" && (result.Killed != 45 || result.Place2 != 478 || result.Place3 != 814))
        {
            failures.Add("instant t3 kills/place " + result.Killed + "/" + result.Place2 + "/" + result.Place3 + " expected 45/478/814");
        }
    }

    private static void Expect(RunResult result, string scenario, BattlePhase phase, int tick, int leaks, int balance, List<string> failures)
    {
        if (result.Scenario != scenario)
        {
            return;
        }

        if (result.Phase != phase || result.Tick != tick || result.Leaks != leaks || result.Balance != balance)
        {
            failures.Add("instant " + scenario + " got " + result.Phase + " tick=" + result.Tick + " leaks=" + result.Leaks + " balance=" + result.Balance + " leakTicks=" + result.LeakTicks);
        }
    }

    private static void CheckDeterminism(SliceBattleContent content, SwordSetup setup, string scenario, RunResult direct, List<string> failures)
    {
        int frames1;
        var clock1 = Replay(content, setup, direct.Places, 1, out frames1);
        int frames2;
        var clock2 = Replay(content, setup, direct.Places, 2, out frames2);
        if (clock1.Fingerprint != direct.Fingerprint || clock2.Fingerprint != direct.Fingerprint)
        {
            failures.Add(setup.Name + " " + scenario + " fingerprint direct=" + direct.Fingerprint + " 1x=" + clock1.Fingerprint + " 2x=" + clock2.Fingerprint + " tick " + direct.Tick + "/" + clock1.Tick + "/" + clock2.Tick);
            return;
        }

        if (clock1.Phase != direct.Phase || clock2.Phase != direct.Phase || clock1.Tick != direct.Tick || clock2.Tick != direct.Tick || clock1.Balance != direct.Balance || clock2.Balance != direct.Balance || clock1.Leaks != direct.Leaks || clock2.Leaks != direct.Leaks)
        {
            failures.Add(setup.Name + " " + scenario + " clock finals diverged");
            return;
        }

        if (!(frames2 < frames1 * 0.6) || !(frames2 > frames1 * 0.4))
        {
            failures.Add(setup.Name + " " + scenario + " 2x frames " + frames2 + " were not about half of 1x " + frames1);
        }
    }

    private static void ProbeFloor(List<string> failures)
    {
        var content = Straight(0.28, 0, 10, 120);
        CombatSimulation sim;
        string error;
        if (!CombatSimulation.TryCreate(content, out sim, out error))
        {
            failures.Add("floor create: " + error);
            return;
        }

        try
        {
            sim.EnableSwordProjectiles(0.039, true);
            failures.Add("speed 0.039 was accepted");
        }
        catch (ArgumentOutOfRangeException)
        {
        }

        try
        {
            sim.EnableSwordProjectiles(CombatSimulation.MinSwordSpeedPerTick, true);
        }
        catch (Exception exception)
        {
            failures.Add("speed 0.04 rejected: " + exception.Message);
        }
    }

    private static void ProbeFlight(double range, double speed, int expectedTick, List<string> failures)
    {
        var sim = StartProbe(Straight(range, 0, 10, 120), speed, true, "cell");
        var killTick = 0;
        for (var i = 0; i < 12 && sim.Phase == BattlePhase.Running; i++)
        {
            sim.Tick();
            if (sim.KilledEnemies > 0 && killTick == 0)
            {
                killTick = sim.TickCount;
            }
        }

        if (killTick != expectedTick || sim.KilledEnemies != 1 || sim.DissipatedSwords != 0)
        {
            failures.Add("flight speed " + F(speed) + " killTick=" + killTick + " expected=" + expectedTick + " kills=" + sim.KilledEnemies + " dissipated=" + sim.DissipatedSwords + " phase=" + sim.Phase);
        }
    }

    private static void ProbeOverkill(double range, double speed, List<string> failures)
    {
        var sim = StartProbe(Straight(range, 0, 4, 120), speed, true, "cell");
        while (sim.Phase == BattlePhase.Running && sim.TickCount < 12)
        {
            sim.Tick();
        }

        if (sim.OverkillDamage != 6 || sim.KilledEnemies != 1)
        {
            failures.Add("overkill got " + sim.OverkillDamage + " kills=" + sim.KilledEnemies);
        }
    }

    private static void ProbeWaste(double range, double speed, bool reserve, List<string> failures)
    {
        var medium = range / 2.0;
        var content = Straight(range, 0, 10, 500);
        content.Level.BuildCells.Add(new BuildCellDefinition { Id = "cell-b", X = medium, Y = 0.5 });
        var sim = StartProbe(content, speed, reserve, "cell", "cell-b");
        while (sim.Phase == BattlePhase.Running && sim.TickCount < 12)
        {
            sim.Tick();
        }

        if (reserve)
        {
            if (sim.SwordsFired != 1 || sim.DissipatedSwords != 0 || sim.ReservedHoldShots < 1 || sim.KilledEnemies != 1)
            {
                failures.Add("R hold fired=" + sim.SwordsFired + " dissipated=" + sim.DissipatedSwords + " holds=" + sim.ReservedHoldShots + " kills=" + sim.KilledEnemies);
            }
        }
        else if (sim.SwordsFired != 2 || sim.SwordsLanded != 1 || sim.DissipatedSwords != 1 || sim.OverkillDamage != 0 || sim.KilledEnemies != 1)
        {
            failures.Add("waste fired=" + sim.SwordsFired + " landed=" + sim.SwordsLanded + " dissipated=" + sim.DissipatedSwords + " overkill=" + sim.OverkillDamage);
        }
    }

    private static void ProbeHoming(double speed, List<string> failures)
    {
        var content = new SliceBattleContent
        {
            Tower = Tower(0.28),
            Enemy = Enemy(0.02, 10),
            Level = Level(
                new[]
                {
                    new WaypointDefinition { Id = "a", X = 0, Y = 0 },
                    new WaypointDefinition { Id = "b", X = 0.30, Y = 0 },
                    new WaypointDefinition { Id = "c", X = 0.30, Y = 0.80 },
                },
                new[] { new BuildCellDefinition { Id = "cell", X = 0.14, Y = 0.14 } },
                120),
        };
        var sim = StartProbe(content, speed, true, "cell");
        while (sim.Phase == BattlePhase.Running && sim.TickCount < 40)
        {
            sim.Tick();
        }

        if (sim.Phase != BattlePhase.Won || sim.KilledEnemies != 1 || sim.LeakCount != 0)
        {
            failures.Add("homing phase=" + sim.Phase + " tick=" + sim.TickCount + " kills=" + sim.KilledEnemies + " leaks=" + sim.LeakCount);
        }
    }

    private static int ExpectedHitTick(double distance, double speed)
    {
        var tick = 1;
        var remaining = distance;
        while (tick < 30)
        {
            tick++;
            if (remaining <= speed + 1e-9)
            {
                return tick;
            }

            remaining -= speed;
        }

        return tick;
    }

    private static CombatSimulation StartProbe(SliceBattleContent content, double speed, bool reserve, params string[] cells)
    {
        CombatSimulation sim;
        string error;
        if (!CombatSimulation.TryCreate(content, out sim, out error))
        {
            throw new InvalidOperationException(error);
        }

        sim.EnableSwordProjectiles(speed, reserve);
        for (var i = 0; i < cells.Length; i++)
        {
            sim.EnqueuePlace(content.Tower.Id, cells[i]);
        }

        sim.Begin();
        return sim;
    }

    private static SliceBattleContent Straight(double range, double enemySpeed, int hp, int starting)
    {
        var medium = range / 2.0;
        var built = new List<BuildCellDefinition>
        {
            new BuildCellDefinition { Id = "cell", X = medium, Y = 0.5 },
        };
        return new SliceBattleContent
        {
            Tower = Tower(range),
            Enemy = Enemy(enemySpeed, hp),
            Level = Level(
                new[]
                {
                    new WaypointDefinition { Id = "a", X = 0, Y = 0.5 },
                    new WaypointDefinition { Id = "b", X = 1, Y = 0.5 },
                },
                built.ToArray(),
                starting),
        };
    }

    private static TowerDefinition Tower(double range)
    {
        return new TowerDefinition
        {
            Id = SliceRules.SliceTowerId,
            Damage = 10,
            Range = range,
            AttackIntervalTicks = 8,
            TargetPriority = SliceRules.TargetFirstAlongPath,
            BuildCost = 100,
        };
    }

    private static EnemyDefinition Enemy(double speed, int hp)
    {
        return new EnemyDefinition
        {
            Id = SliceRules.SliceEnemyId,
            MaxHp = hp,
            Speed = speed,
            LeakDamage = 1,
            RewardCurrencyId = "lingshi",
            RewardAmount = 8,
        };
    }

        private static LevelDefinition Level(WaypointDefinition[] points, BuildCellDefinition[] cells, int starting)
    {
        return new LevelDefinition
        {
            Id = SliceRules.SliceLevelId,
            Space = SliceRules.SpaceHeightUnits16x9,
            Waypoints = new List<WaypointDefinition>(points),
            Waves = new List<WaveDefinition>
            {
                new WaveDefinition
                {
                    Id = "wave_01",
                    Spawns = new List<SpawnDefinition>
                    {
                        new SpawnDefinition
                        {
                            EnemyId = SliceRules.SliceEnemyId,
                            Count = 1,
                            IntervalTicks = 48,
                            HpMultiplier = 1,
                        },
                    },
                },
            },
            BuildCells = new List<BuildCellDefinition>(cells),
            Economy = new LevelEconomyDefinition
            {
                CurrencyId = "lingshi",
                StartingAmount = starting,
                WaveClearBase = 15,
                WaveClearPerWaveIndex = 5,
            },
            WinRule = SliceRules.WinAllWavesCleared,
            LoseRule = SliceRules.LoseLeakCount,
            LoseLeakCount = 3,
        };
    }

    private static RunResult Run(SliceBattleContent content, SwordSetup setup, string scenario)
    {
        var sim = Create(content, setup);
        var places = new List<PlaceEvent>();
        var opening = OpeningCell(content, scenario);
        if (opening != null)
        {
            sim.EnqueuePlace(content.Tower.Id, opening);
            places.Add(new PlaceEvent { AfterTick = -1, CellId = opening });
        }

        sim.Begin();
        return Drive(sim, content, scenario, places);
    }

    private static RunResult Replay(SliceBattleContent content, SwordSetup setup, List<PlaceEvent> places, int clockSpeed, out int frames)
    {
        var sim = Create(content, setup);
        for (var i = 0; i < places.Count; i++)
        {
            if (places[i].AfterTick < 0)
            {
                sim.EnqueuePlace(content.Tower.Id, places[i].CellId);
            }
        }

        sim.Begin();
        var clock = new SimClock();
        clock.SetSpeed(clockSpeed);
        frames = 0;
        var cursor = 0;
        while (cursor < places.Count && places[cursor].AfterTick < 0)
        {
            cursor++;
        }

        var hash = 17;
        var guard = 0;
        var leakTicks = new List<int>();
        var previousLeaks = 0;
        var place2 = 0;
        var place3 = 0;
        var previousTowers = 0;
        while (sim.Phase == BattlePhase.Running && guard++ < 400000)
        {
            frames++;
            var step = clock.ConsumeTicks(1.0 / 60.0);
            for (var i = 0; i < step; i++)
            {
                if (sim.Phase != BattlePhase.Running)
                {
                    break;
                }

                sim.Tick();
                hash = Mix(hash, sim);
                if (sim.LeakCount > previousLeaks)
                {
                    leakTicks.Add(sim.TickCount);
                    previousLeaks = sim.LeakCount;
                }

                var towers = sim.Snapshot.Towers.Count;
                if (previousTowers < 2 && towers >= 2)
                {
                    place2 = sim.TickCount;
                }

                if (previousTowers < 3 && towers >= 3)
                {
                    place3 = sim.TickCount;
                }

                previousTowers = towers;
                while (cursor < places.Count && places[cursor].AfterTick == sim.TickCount)
                {
                    sim.EnqueuePlace(content.Tower.Id, places[cursor].CellId);
                    cursor++;
                }
            }
        }

        return Snapshot(setup == null ? "instant" : setup.Name, "replay", sim, leakTicks, place2, place3, hash, places);
    }

    private static RunResult Drive(CombatSimulation sim, SliceBattleContent content, string scenario, List<PlaceEvent> places)
    {
        var hash = 17;
        var leakTicks = new List<int>();
        var previousLeaks = 0;
        var place2 = 0;
        var place3 = 0;
        var previousTowers = 0;
        var triedFourth = false;
        var guard = 0;
        while (sim.Phase == BattlePhase.Running && guard++ < GuardTicks)
        {
            sim.Tick();
            hash = Mix(hash, sim);
            if (sim.LeakCount > previousLeaks)
            {
                leakTicks.Add(sim.TickCount);
                previousLeaks = sim.LeakCount;
            }

            var towers = sim.Snapshot.Towers.Count;
            if (previousTowers < 2 && towers >= 2)
            {
                place2 = sim.TickCount;
            }

            if (previousTowers < 3 && towers >= 3)
            {
                place3 = sim.TickCount;
            }

            previousTowers = towers;
            if (sim.Phase != BattlePhase.Running)
            {
                break;
            }

            MaybeBuild(sim, content, scenario, places, ref triedFourth);
        }

        return Snapshot(sim.SwordProjectilesEnabled ? F(sim.SwordSpeedPerTick) + (sim.SwordReserveIncoming ? "-R" : "-noR") : "instant", scenario, sim, leakTicks, place2, place3, hash, places);
    }

    private static void MaybeBuild(CombatSimulation sim, SliceBattleContent content, string scenario, List<PlaceEvent> places, ref bool triedFourth)
    {
        if (scenario != "t2" && scenario != "t3")
        {
            return;
        }

        var limit = scenario == "t2" ? 2 : 3;
        if (sim.Snapshot.Towers.Count >= limit)
        {
            if (scenario == "t3" && !triedFourth)
            {
                triedFourth = true;
                var occupied = content.Level.BuildCells[0].Id;
                sim.EnqueuePlace(content.Tower.Id, occupied);
                places.Add(new PlaceEvent { AfterTick = sim.TickCount, CellId = occupied });
            }

            return;
        }

        if (sim.Balance < content.Tower.BuildCost)
        {
            return;
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
            places.Add(new PlaceEvent { AfterTick = sim.TickCount, CellId = free });
        }
    }

    private static string OpeningCell(SliceBattleContent content, string scenario)
    {
        if (scenario == "none")
        {
            return null;
        }

        if (scenario == "02")
        {
            return "cell_jin_02";
        }

        if (scenario == "03")
        {
            return "cell_jin_03";
        }

        return content.Level.BuildCells[0].Id;
    }

    private static CombatSimulation Create(SliceBattleContent content, SwordSetup setup)
    {
        CombatSimulation sim;
        string error;
        if (!CombatSimulation.TryCreate(content, out sim, out error))
        {
            throw new InvalidOperationException(error);
        }

        if (setup != null)
        {
            sim.EnableSwordProjectiles(setup.Speed, setup.Reserve);
        }

        return sim;
    }

    private static RunResult Snapshot(string config, string scenario, CombatSimulation sim, List<int> leakTicks, int place2, int place3, int hash, List<PlaceEvent> places)
    {
        var perTower = "-";
        if (sim.Snapshot.Towers.Count > 0)
        {
            perTower = "";
            for (var i = 0; i < sim.Snapshot.Towers.Count; i++)
            {
                var cell = sim.Snapshot.Towers[i].CellId;
                if (perTower.Length > 0)
                {
                    perTower += " ";
                }

                perTower += cell.Substring(cell.Length - 2) + "=" + sim.MaxSwordInFlight(cell);
            }
        }

        return new RunResult
        {
            Config = config,
            Scenario = scenario,
            Phase = sim.Phase,
            Tick = sim.TickCount,
            Leaks = sim.LeakCount,
            LeakTicks = Join(leakTicks),
            LeakHps = Join(sim.LeakRemainingHp),
            Balance = sim.Balance,
            Killed = sim.KilledEnemies,
            Dissipated = sim.DissipatedSwords,
            Doomed = sim.UnresolvedDoomedSwords,
            Chasing = sim.SwordsStillChasing,
            Overkill = sim.OverkillDamage,
            Holds = sim.ReservedHoldShots,
            Fired = sim.SwordsFired,
            Landed = sim.SwordsLanded,
            MaxFlight = sim.MaxSwordInFlightTotal,
            PerTower = perTower,
            Place2 = place2,
            Place3 = place3,
            Spent = sim.TotalBuildSpent,
            KillReward = sim.TotalKillRewards,
            WaveClear = sim.TotalWaveClearRewards,
            SurvivorRemain = sim.SawSurvivorApproach ? sim.ClosestSurvivorRemaining : -1,
            SurvivorHp = sim.ClosestSurvivorHp,
            SurvivorTick = sim.ClosestSurvivorTick,
            Fingerprint = hash,
            Places = places,
        };
    }

    private static int Mix(int hash, CombatSimulation sim)
    {
        unchecked
        {
            hash = (hash * 31) + sim.TickCount;
            hash = (hash * 31) + (int)sim.Phase;
            hash = (hash * 31) + sim.LeakCount;
            hash = (hash * 31) + sim.Balance;
            hash = (hash * 31) + sim.KilledEnemies;
            hash = (hash * 31) + sim.DissipatedSwords;
            hash = (hash * 31) + sim.UnresolvedDoomedSwords;
            hash = (hash * 31) + sim.SwordsStillChasing;
            hash = (hash * 31) + sim.OverkillDamage;
            hash = (hash * 31) + sim.ReservedHoldShots;
            hash = (hash * 31) + sim.SwordsFired;
            hash = (hash * 31) + sim.SwordsLanded;
            hash = (hash * 31) + sim.MaxSwordInFlightTotal;
            var enemies = sim.Snapshot.Enemies;
            hash = (hash * 31) + enemies.Count;
            for (var i = 0; i < enemies.Count; i++)
            {
                var enemy = enemies[i];
                hash = (hash * 31) + enemy.InstanceId;
                hash = (hash * 31) + enemy.Hp;
                hash = (hash * 31) + Bits(enemy.Distance);
                hash = (hash * 31) + Bits(enemy.X);
                hash = (hash * 31) + Bits(enemy.Y);
            }

            var towers = sim.Snapshot.Towers;
            hash = (hash * 31) + towers.Count;
            for (var i = 0; i < towers.Count; i++)
            {
                var id = towers[i].CellId;
                for (var c = 0; c < id.Length; c++)
                {
                    hash = (hash * 31) + id[c];
                }
            }

            return hash;
        }
    }

    private static int Bits(double value)
    {
        var bits = BitConverter.DoubleToInt64Bits(value);
        unchecked
        {
            return (int)(bits ^ (bits >> 32));
        }
    }

    private static void PrintRuns(string title, List<RunResult> runs)
    {
        Console.WriteLine("--- " + title + " ---");
        Console.WriteLine("config scenario phase tick leaks leakTicks balance kills waste(diss+doom) overkill maxFlight perTower holds fired landed place2 place3 spent killReward waveClear leakHps survivor");
        for (var i = 0; i < runs.Count; i++)
        {
            var run = runs[i];
            Console.WriteLine(string.Join(" ", new string[]
            {
                run.Config,
                run.Scenario,
                run.Phase.ToString(),
                run.Tick.ToString(CultureInfo.InvariantCulture),
                run.Leaks.ToString(CultureInfo.InvariantCulture),
                run.LeakTicks,
                run.Balance.ToString(CultureInfo.InvariantCulture),
                run.Killed.ToString(CultureInfo.InvariantCulture),
                run.Dissipated.ToString(CultureInfo.InvariantCulture) + "+" + run.Doomed.ToString(CultureInfo.InvariantCulture),
                run.Overkill.ToString(CultureInfo.InvariantCulture),
                run.MaxFlight.ToString(CultureInfo.InvariantCulture),
                run.PerTower,
                run.Holds.ToString(CultureInfo.InvariantCulture),
                run.Fired.ToString(CultureInfo.InvariantCulture),
                run.Landed.ToString(CultureInfo.InvariantCulture),
                run.Place2.ToString(CultureInfo.InvariantCulture),
                run.Place3.ToString(CultureInfo.InvariantCulture),
                run.Spent.ToString(CultureInfo.InvariantCulture),
                run.KillReward.ToString(CultureInfo.InvariantCulture),
                run.WaveClear.ToString(CultureInfo.InvariantCulture),
                run.LeakHps,
                F(run.SurvivorRemain) + "@" + run.SurvivorTick.ToString(CultureInfo.InvariantCulture) + "hp" + run.SurvivorHp.ToString(CultureInfo.InvariantCulture) + " chase" + run.Chasing.ToString(CultureInfo.InvariantCulture),
            }));
        }
    }

    private static void PrintComparison(List<RunResult> runs, Dictionary<string, RunResult> instant)
    {
        Console.WriteLine("--- versus instant leaks/lingshi/tick ---");
        for (var i = 0; i < runs.Count; i++)
        {
            var run = runs[i];
            RunResult baseline;
            if (!instant.TryGetValue(run.Scenario, out baseline))
            {
                continue;
            }

            var leakSame = run.Leaks == baseline.Leaks && run.LeakTicks == baseline.LeakTicks;
            var moneySame = run.Balance == baseline.Balance;
            Console.WriteLine(run.Config + " " + run.Scenario
                + " leak" + (leakSame ? "=same" : " DIFF " + run.Leaks + " vs " + baseline.Leaks + " ticks " + run.LeakTicks + " vs " + baseline.LeakTicks)
                + " lingshi" + (moneySame ? "=same" : " DIFF " + run.Balance + " vs " + baseline.Balance)
                + " tickΔ" + (run.Tick - baseline.Tick).ToString(CultureInfo.InvariantCulture)
                + " killΔ" + (run.Killed - baseline.Killed).ToString(CultureInfo.InvariantCulture));
        }

        Console.WriteLine("--- versus pre-run (homing, R on) ---");
        ExpectPre(runs, "align-0.04-R", "02", BattlePhase.Lost, 2135, 449, 0);
        ExpectPre(runs, "align-0.04-R", "t2", BattlePhase.Won, 1982, 540, 482);
        ExpectPre(runs, "align-0.08-R", "02", BattlePhase.Lost, 2135, 449, 0);
        ExpectPre(runs, "align-0.08-R", "t2", BattlePhase.Won, 1980, 540, 480);
    }

    private static void ExpectPre(List<RunResult> runs, string config, string scenario, BattlePhase phase, int tick, int balance, int place2)
    {
        for (var i = 0; i < runs.Count; i++)
        {
            var run = runs[i];
            if (run.Config != config || run.Scenario != scenario)
            {
                continue;
            }

            var same = run.Phase == phase && run.Tick == tick && run.Balance == balance && (place2 == 0 || run.Place2 == place2) && (phase == BattlePhase.Lost ? run.Leaks == 3 : run.Leaks == 0);
            Console.WriteLine(config + " " + scenario + (same ? " MATCH pre-run" : " DIFF pre-run got " + run.Phase + " tick=" + run.Tick + " leaks=" + run.Leaks + " balance=" + run.Balance + " place2=" + run.Place2 + " expected tick=" + tick + " balance=" + balance + " place2=" + place2));
            return;
        }
    }

    private static void PrintGoals(List<RunResult> runs)
    {
        Console.WriteLine("--- product goal: every single cell loses, 2 towers win with 0 leaks ---");
        var configs = new List<string>();
        for (var i = 0; i < runs.Count; i++)
        {
            if (!configs.Contains(runs[i].Config))
            {
                configs.Add(runs[i].Config);
            }
        }

        for (var c = 0; c < configs.Count; c++)
        {
            var config = configs[c];
            var singles = true;
            RunResult two = null;
            for (var i = 0; i < runs.Count; i++)
            {
                if (runs[i].Config != config)
                {
                    continue;
                }

                if (runs[i].Scenario == "01" || runs[i].Scenario == "02" || runs[i].Scenario == "03")
                {
                    if (runs[i].Phase != BattlePhase.Lost)
                    {
                        singles = false;
                    }
                }

                if (runs[i].Scenario == "t2")
                {
                    two = runs[i];
                }
            }

            var twoOk = two != null && two.Phase == BattlePhase.Won && two.Leaks == 0;
            Console.WriteLine(config + " goal=" + (singles && twoOk ? "YES" : "NO") + " singlesLose=" + singles + " two=" + (two == null ? "missing" : two.Phase + " leaks=" + two.Leaks + " tick=" + two.Tick + " balance=" + two.Balance));
            if (two != null && !twoOk)
            {
                var hearts = 3 - two.Leaks;
                if (hearts < 0)
                {
                    hearts = 0;
                }

                Console.WriteLine("MARGIN " + config + " dingHearts=" + hearts + " leakHps=" + two.LeakHps + " leakTicks=" + two.LeakTicks + " survivorRemain=" + F(two.SurvivorRemain) + " survivorHp=" + two.SurvivorHp + " survivorTick=" + two.SurvivorTick);
            }
        }
    }

    private static SliceBattleContent LoadSlice(List<string> failures)
    {
        var root = FindRoot();
        var tower = File.ReadAllText(Path.Combine(root, "content", "towers", "tower_jin.json"));
        var enemy = File.ReadAllText(Path.Combine(root, "content", "enemies", "enemy_dangkang.json"));
        var level = File.ReadAllText(Path.Combine(root, "content", "levels", "level_jizhou_01.json"));
        SliceBattleContent content;
        string error;
        if (!SliceTables.TryParse(tower, enemy, level, SliceRules.SliceLevelId, out content, out error))
        {
            failures.Add("slice load: " + error);
            return null;
        }

        return content;
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

    private static string Join(IReadOnlyList<int> values)
    {
        if (values == null || values.Count == 0)
        {
            return "-";
        }

        var text = values[0].ToString(CultureInfo.InvariantCulture);
        for (var i = 1; i < values.Count; i++)
        {
            text += "," + values[i].ToString(CultureInfo.InvariantCulture);
        }

        return text;
    }

    private static string F(double value)
    {
        return value.ToString("G17", CultureInfo.InvariantCulture);
    }

    private static int Fail(List<string> failures)
    {
        Console.Error.WriteLine("experiment failed:");
        for (var i = 0; i < failures.Count; i++)
        {
            Console.Error.WriteLine(" - " + failures[i]);
        }

        return 1;
    }

    private sealed class SwordSetup
    {
        public SwordSetup(string name, double speed, bool reserve)
        {
            Name = name;
            Speed = speed;
            Reserve = reserve;
        }

        public string Name;
        public double Speed;
        public bool Reserve;
    }

    private struct PlaceEvent
    {
        public int AfterTick;
        public string CellId;
    }

    private sealed class RunResult
    {
        public string Config;
        public string Scenario;
        public BattlePhase Phase;
        public int Tick;
        public int Leaks;
        public string LeakTicks;
        public string LeakHps;
        public int Balance;
        public int Killed;
        public int Dissipated;
        public int Doomed;
        public int Chasing;
        public int Overkill;
        public int Holds;
        public int Fired;
        public int Landed;
        public int MaxFlight;
        public string PerTower;
        public int Place2;
        public int Place3;
        public int Spent;
        public int KillReward;
        public int WaveClear;
        public double SurvivorRemain;
        public int SurvivorHp;
        public int SurvivorTick;
        public int Fingerprint;
        public List<PlaceEvent> Places;
    }

    private sealed class PathLength
    {
        public PathLength(SliceBattleContent content)
        {
            Value = new ShanhaiDingGuard.Gameplay.Path.PathCurve(content.Level.Waypoints).Length;
        }

        public double Value;
    }
}
