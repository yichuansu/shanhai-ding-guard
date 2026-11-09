namespace ShanhaiDingGuard.Gameplay.Hero
{
    /// <summary>
    /// 可操控英雄。M3 之前是空实现，M1 的技能队列没有条目。
    /// </summary>
    public interface IHeroActions
    {
        void SettleTick();
    }

    public sealed class IdleHero : IHeroActions
    {
        public void SettleTick()
        {
        }
    }
}
