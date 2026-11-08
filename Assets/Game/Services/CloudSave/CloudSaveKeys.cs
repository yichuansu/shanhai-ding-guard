namespace ShanhaiDingGuard.Services.CloudSave
{
    public static class CloudSaveKeys
    {
        /// <summary>
        /// UGS Cloud Save 玩家数据键。
        /// 生产实现使用 CloudSaveService.Instance.Data.Player，把档案 JSON 存在这个键上。
        /// </summary>
        public const string PlayerProfile = "shdg.save";
    }
}
