using System;
using System.Collections.Generic;
using ShanhaiDingGuard.Gameplay.CombatSimulation;

namespace ShanhaiDingGuard.Gameplay.Towers
{
    public static class TowerTargeting
    {
        public static EnemyUnit FirstAlongPath(IReadOnlyList<EnemyUnit> enemies, double towerX, double towerY, double range)
        {
            return FirstAlongPath(enemies, towerX, towerY, range, null);
        }

        /// <summary>
        /// 与无过滤版本同一优先级：沿路径最远，等距取更小 InstanceId。
        /// eligible 为 false 的敌人跳过。即时命中不传过滤。
        /// </summary>
        public static EnemyUnit FirstAlongPath(
            IReadOnlyList<EnemyUnit> enemies,
            double towerX,
            double towerY,
            double range,
            Func<EnemyUnit, bool> eligible)
        {
            EnemyUnit best = null;
            var rangeSquared = range * range;
            for (var i = 0; i < enemies.Count; i++)
            {
                var enemy = enemies[i];
                if (!enemy.Alive)
                {
                    continue;
                }

                if (eligible != null && !eligible(enemy))
                {
                    continue;
                }

                var dx = enemy.X - towerX;
                var dy = enemy.Y - towerY;
                if ((dx * dx) + (dy * dy) > rangeSquared + 1e-9)
                {
                    continue;
                }

                if (best == null
                    || enemy.Distance > best.Distance + 1e-9
                    || (Math.Abs(enemy.Distance - best.Distance) <= 1e-9 && enemy.InstanceId < best.InstanceId))
                {
                    best = enemy;
                }
            }

            return best;
        }
    }
}
