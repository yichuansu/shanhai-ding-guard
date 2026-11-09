namespace ShanhaiDingGuard.Gameplay.CombatSimulation
{
    /// <summary>
    /// 把墙钟推进换成模拟 tick。倍速只放大这里的累计时间。
    /// 1 倍速下每个 tick 是 0.1 秒墙钟（10 Hz）。这是切片手感，不是已锁定的设计值。
    /// </summary>
    public sealed class SimClock
    {
        public const double TickSeconds = 0.1;

        private const int TickCapPerFrame = 40;

        public int Speed { get; private set; } = 1;

        public double Accumulator { get; private set; }

        public void SetSpeed(int speed)
        {
            Speed = speed == 2 ? 2 : 1;
        }

        public void ToggleSpeed()
        {
            Speed = Speed == 1 ? 2 : 1;
        }

        public int ConsumeTicks(double deltaSeconds)
        {
            if (deltaSeconds < 0)
            {
                deltaSeconds = 0;
            }

            Accumulator += deltaSeconds * Speed;
            var ticks = 0;
            while (Accumulator >= TickSeconds && ticks < TickCapPerFrame)
            {
                Accumulator -= TickSeconds;
                ticks++;
            }

            if (ticks >= TickCapPerFrame && Accumulator > TickSeconds)
            {
                Accumulator = TickSeconds;
            }

            return ticks;
        }

        public double InterpolationAlpha
        {
            get
            {
                var alpha = Accumulator / TickSeconds;
                if (alpha < 0)
                {
                    return 0;
                }

                if (alpha > 1)
                {
                    return 1;
                }

                return alpha;
            }
        }
    }
}
