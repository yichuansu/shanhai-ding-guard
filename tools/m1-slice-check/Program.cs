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
        SliceBattleContent content = null;
        string error = null;
        if (!TryLoadSlice(root, out content, out error))
        {
            failures.Add("slice load: " + error);
        }
        else
        {
            CheckShape(content, failures);
            CheckWin(content, failures);
            CheckLose(content, failures);
            CheckSpeedDoesNotChangeDamageOrTickCount(content, failures);
            CheckTickBeforeBeginDoesNothing(content, failures);
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
        return 0;
    }

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

    private static void CheckShape(SliceBattleContent content, List<string> failures)
    {
        if (content.Level.Waves.Count != 3)
        {
            failures.Add("expected 3 waves, got " + content.Level.Waves.Count);
        }

        if (content.Level.Waypoints.Count < 2)
        {
            failures.Add("path is missing waypoints");
        }

        if (content.Enemy.Element != null)
        {
            failures.Add("M1 enemy element should stay null");
        }

        if (content.Tower.TargetPriority != SliceRules.TargetFirstAlongPath)
        {
            failures.Add("target priority drifted");
        }

        if (content.Level.LoseRule != SliceRules.LoseLeakCount || content.Level.LoseLeakCount != 1)
        {
            failures.Add("lose rule is not leak_count 1");
        }

        var enemies = 0;
        for (var i = 0; i < content.Level.Waves.Count; i++)
        {
            enemies += content.Level.Waves[i].Spawns[0].Count;
        }

        if (enemies < 3)
        {
            failures.Add("waves have no enemies");
        }
    }

    private static void CheckWin(SliceBattleContent content, List<string> failures)
    {
        var sim = StartPlaced(content);
        var hits = new List<int>();
        var guard = 0;
        while (sim.Phase == BattlePhase.Running && guard++ < 20000)
        {
            sim.Tick();
            if (sim.LastHitDamage != 0)
            {
                hits.Add(sim.LastHitDamage);
            }
        }

        if (sim.Phase != BattlePhase.Won)
        {
            failures.Add("placed tower should win, phase=" + sim.Phase + " tick=" + sim.TickCount + " leaks=" + sim.LeakCount + " alive=" + sim.Snapshot.Enemies.Count);
            return;
        }

        if (sim.LeakCount != 0)
        {
            failures.Add("win should have zero leaks");
        }

        if (hits.Count == 0)
        {
            failures.Add("tower never fired");
        }

        for (var i = 0; i < hits.Count; i++)
        {
            if (hits[i] != content.Tower.Damage)
            {
                failures.Add("hit damage " + hits[i] + " != table damage " + content.Tower.Damage);
                break;
            }
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
        while (sim.Phase == BattlePhase.Running && guard++ < 20000)
        {
            sim.Tick();
        }

        if (sim.Phase != BattlePhase.Lost)
        {
            failures.Add("no tower should lose, phase=" + sim.Phase + " tick=" + sim.TickCount);
            return;
        }

        if (sim.LeakCount != content.Level.LoseLeakCount)
        {
            failures.Add("leak count " + sim.LeakCount + " != " + content.Level.LoseLeakCount);
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
        }

        if (!(frames2 < frames1 * 0.6) || !(frames2 > frames1 * 0.4))
        {
            failures.Add("2x wall frames " + frames2 + " were not about half of 1x " + frames1);
        }
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
                if (sim.LastHitDamage != 0 && sim.LastHitDamage != content.Tower.Damage)
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
