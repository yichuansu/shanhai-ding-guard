namespace ShanhaiDingGuard.Services.Analytics
{
    public sealed class NoOpAnalyticsService : IAnalyticsService
    {
        public void Track(string eventName)
        {
        }
    }
}
