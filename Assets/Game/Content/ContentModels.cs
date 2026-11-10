using System.Collections.Generic;

namespace ShanhaiDingGuard.Content
{
    /// <summary>
    /// M1 切片用到的规则 id。形状样例里的 leak_rule_tbd 不是可玩规则。
    /// </summary>
    public static class SliceRules
    {
        public const int SchemaVersion = 0;
        public const string TowerSchema = "shdg.tower";
        public const string EnemySchema = "shdg.enemy";
        public const string LevelSchema = "shdg.level.waves";
        /// <summary>
        /// 旧切片坐标系：x、y 都在 [0, 1]。冀州 01 已迁到 <see cref="SpaceHeightUnits16x9"/>。
        /// 加载器仍接受这套边界，避免旧表直接读失败。
        /// </summary>
        public const string SpaceNormalizedPlayfield = "normalized_playfield";

        /// <summary>
        /// 16:9 高度单位。x ∈ [0, 1.778] 从左到右，y ∈ [0, 1] 从下到上，(0,0) 为左下。
        /// 1.778 是 16/9 保留三位小数。射程和沿路径速度都用这一套单位。
        /// </summary>
        public const string SpaceHeightUnits16x9 = "height_units_16x9";

        public const double HeightUnits16x9MaxX = 1.778;
        public const double HeightUnits16x9MaxY = 1.0;
        public const double NormalizedPlayfieldMax = 1.0;

        public static bool TryGetBounds(string space, out double maxX, out double maxY, out string error)
        {
            if (space == SpaceHeightUnits16x9)
            {
                maxX = HeightUnits16x9MaxX;
                maxY = HeightUnits16x9MaxY;
                error = null;
                return true;
            }

            if (space == SpaceNormalizedPlayfield)
            {
                maxX = NormalizedPlayfieldMax;
                maxY = NormalizedPlayfieldMax;
                error = null;
                return true;
            }

            maxX = 0;
            maxY = 0;
            error = "space 无法识别，已保留原文件";
            return false;
        }

        public const string TargetFirstAlongPath = "first_along_path";
        public const string WinAllWavesCleared = "all_waves_cleared";

        /// <summary>
        /// 漏出终点的敌人数达到关卡上的 loseLeakCount 即负。
        /// leakDamage 只累计，不折成基地生命。
        /// </summary>
        public const string LoseLeakCount = "leak_count";

        public const string SliceTowerId = "tower_jin";
        public const string SliceEnemyId = "enemy_dangkang";
        public const string SliceLevelId = "level_jizhou_01";

        /// <summary>M1 垂直切片。正式表改为 <see cref="SliceIdJizhou01Formal"/>，两者都可进战斗。</summary>
        public const string SliceIdM1 = "m1";

        public const string SliceIdJizhou01Formal = "jizhou_01_formal";

        public static bool IsAcceptedSlice(string slice)
        {
            return slice == SliceIdM1 || slice == SliceIdJizhou01Formal;
        }
    }

    public sealed class TowerDefinition
    {
        public string Id;
        public string DisplayName;
        public string Element;
        public int BuildCost;
        public int Damage;
        public double Range;
        public int AttackIntervalTicks;
        public string TargetPriority;
        public bool MergeEnabled;
    }

    public sealed class EnemyDefinition
    {
        public string Id;
        public string DisplayName;

        /// <summary>五行 id。M1 允许 null，结算时不乘相克倍率。</summary>
        public string Element;

        public int MaxHp;
        public double Speed;
        public int LeakDamage;
        public string RewardCurrencyId;
        public int RewardAmount;
    }

    public sealed class WaypointDefinition
    {
        public string Id;
        public double X;
        public double Y;
    }

    public sealed class SpawnDefinition
    {
        public string EnemyId;
        public int Count;
        public int IntervalTicks;

        /// <summary>缺省 1。生成 maxHp = round(敌人 maxHp × 本字段)。</summary>
        public double HpMultiplier;
    }

    public sealed class WaveDefinition
    {
        public string Id;
        public List<SpawnDefinition> Spawns;
    }

    public sealed class BuildCellDefinition
    {
        public string Id;
        public double X;
        public double Y;
    }

    public sealed class LevelEconomyDefinition
    {
        public string CurrencyId;
        public int StartingAmount;
        public int WaveClearBase;
        public int WaveClearPerWaveIndex;
    }

    public sealed class LevelDefinition
    {
        public string Id;
        public string DisplayName;
        public string PathId;
        public string Space;

        /// <summary>可选。战斗背景 sprite 名，与 pathId 绑定。缺省表示没有定稿背景。</summary>
        public string Background;
        public List<WaypointDefinition> Waypoints;
        public List<WaveDefinition> Waves;
        public List<BuildCellDefinition> BuildCells;
        public LevelEconomyDefinition Economy;
        public string WinRule;
        public string LoseRule;
        public int LoseLeakCount;
    }

    public sealed class SliceBattleContent
    {
        public TowerDefinition Tower;
        public EnemyDefinition Enemy;
        public LevelDefinition Level;
    }
}
