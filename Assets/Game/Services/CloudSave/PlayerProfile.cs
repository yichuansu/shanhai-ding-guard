using System.Collections.Generic;

namespace ShanhaiDingGuard.Services.CloudSave
{
    public sealed class PlayerProfile
    {
        public const string SchemaId = "shdg.save";
        public const int CurrentSchemaVersion = 0;

        public string Schema = SchemaId;
        public int SchemaVersion = CurrentSchemaVersion;
        public string AccountId = string.Empty;
        public Dictionary<string, int> Currencies = new Dictionary<string, int>();
        public string LevelProgressJson = "{}";
        public List<string> ShanhaijingUnlocks = new List<string>();
        public int SimulationSpeed = 1;

        public static PlayerProfile CreateEmpty(string playerId)
        {
            return new PlayerProfile
            {
                Schema = SchemaId,
                SchemaVersion = CurrentSchemaVersion,
                AccountId = playerId ?? string.Empty,
                Currencies = new Dictionary<string, int>(),
                LevelProgressJson = "{}",
                ShanhaijingUnlocks = new List<string>(),
                SimulationSpeed = 1,
            };
        }
    }
}
