namespace ShanhaiDingGuard.Services.CloudSave
{
    public static class CloudSaveKeys
    {
        /// <summary>
        /// UGS Cloud Save 玩家数据键。UgsCloudSaveService 把档案 JSON 存在这个键上。
        /// Cloud Save 3.4 的说明要求键只含字母、数字、连字符和下划线。本键含点号，仍按已定名称使用。
        /// 若服务端拒绝该键，见 docs/UGS_SETUP.md。本文件不改名。
        /// </summary>
        public const string PlayerProfile = "shdg.save";
    }
}
