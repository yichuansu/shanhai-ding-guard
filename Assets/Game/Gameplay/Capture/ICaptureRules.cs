namespace ShanhaiDingGuard.Gameplay.Capture
{
    /// <summary>
    /// 捕获判定。M5 才发出图鉴解锁意图。M1 不产生意图，也不写档案。
    /// </summary>
    public interface ICaptureRules
    {
        void SettleTick();
    }

    public sealed class IdleCapture : ICaptureRules
    {
        public void SettleTick()
        {
        }
    }
}
