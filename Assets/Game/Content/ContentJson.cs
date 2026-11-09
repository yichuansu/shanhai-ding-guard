using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace ShanhaiDingGuard.Content
{
    public enum JsonKind
    {
        Null = 0,
        Bool = 1,
        Number = 2,
        String = 3,
        Object = 4,
        Array = 5,
    }

    public sealed class JsonNode
    {
        public JsonKind Kind;
        public bool Bool;
        public string Number;
        public string String;
        public Dictionary<string, JsonNode> Object;
        public List<JsonNode> Array;

        public bool TryGetInt(out int value)
        {
            value = 0;
            if (Kind != JsonKind.Number || string.IsNullOrEmpty(Number))
            {
                return false;
            }

            for (var i = 0; i < Number.Length; i++)
            {
                var c = Number[i];
                if (c == '.' || c == 'e' || c == 'E')
                {
                    return false;
                }
            }

            long parsed;
            if (!long.TryParse(Number, NumberStyles.Integer, CultureInfo.InvariantCulture, out parsed))
            {
                return false;
            }

            if (parsed < int.MinValue || parsed > int.MaxValue)
            {
                return false;
            }

            value = (int)parsed;
            return true;
        }

        public bool TryGetDouble(out double value)
        {
            value = 0;
            if (Kind != JsonKind.Number || string.IsNullOrEmpty(Number))
            {
                return false;
            }

            if (!double.TryParse(Number, NumberStyles.Float, CultureInfo.InvariantCulture, out value))
            {
                return false;
            }

            return !double.IsNaN(value) && !double.IsInfinity(value);
        }
    }

    public static class JsonReader
    {
        public static bool TryParse(string json, out JsonNode node, out string error)
        {
            node = null;
            error = null;
            if (string.IsNullOrEmpty(json))
            {
                error = "JSON 无法解析，已保留原文件";
                return false;
            }

            var parser = new Parser(json);
            if (!parser.TryParseValue(0, out node) || !parser.End())
            {
                error = "JSON 无法解析，已保留原文件";
                node = null;
                return false;
            }

            return true;
        }

        public static string Quote(string value)
        {
            var builder = new StringBuilder(value == null ? 2 : value.Length + 2);
            builder.Append('"');
            if (value != null)
            {
                for (var i = 0; i < value.Length; i++)
                {
                    var c = value[i];
                    switch (c)
                    {
                        case '"':
                            builder.Append("\\\"");
                            break;
                        case '\\':
                            builder.Append("\\\\");
                            break;
                        case '\b':
                            builder.Append("\\b");
                            break;
                        case '\f':
                            builder.Append("\\f");
                            break;
                        case '\n':
                            builder.Append("\\n");
                            break;
                        case '\r':
                            builder.Append("\\r");
                            break;
                        case '\t':
                            builder.Append("\\t");
                            break;
                        default:
                            if (c < 0x20)
                            {
                                builder.Append("\\u");
                                builder.Append(((int)c).ToString("x4", CultureInfo.InvariantCulture));
                            }
                            else
                            {
                                builder.Append(c);
                            }

                            break;
                    }
                }
            }

            builder.Append('"');
            return builder.ToString();
        }

        private sealed class Parser
        {
            private readonly string _json;
            private int _index;

            public Parser(string json)
            {
                _json = json;
                if (_json.Length > 0 && _json[0] == '\uFEFF')
                {
                    _index = 1;
                }
            }

            public bool End()
            {
                Skip();
                return _index >= _json.Length;
            }

            public bool TryParseValue(int depth, out JsonNode node)
            {
                node = null;
                if (depth > 32)
                {
                    return false;
                }

                Skip();
                if (_index >= _json.Length)
                {
                    return false;
                }

                var c = _json[_index];
                if (c == '{')
                {
                    return TryParseObject(depth, out node);
                }

                if (c == '[')
                {
                    return TryParseArray(depth, out node);
                }

                if (c == '"')
                {
                    string text;
                    if (!TryParseString(out text))
                    {
                        return false;
                    }

                    node = new JsonNode { Kind = JsonKind.String, String = text };
                    return true;
                }

                if (c == 't' || c == 'f')
                {
                    return TryParseBool(out node);
                }

                if (c == 'n')
                {
                    return TryParseNull(out node);
                }

                return TryParseNumber(out node);
            }

            private bool TryParseObject(int depth, out JsonNode node)
            {
                node = null;
                if (!Eat('{'))
                {
                    return false;
                }

                var map = new Dictionary<string, JsonNode>();
                Skip();
                if (Peek('}'))
                {
                    _index++;
                    node = new JsonNode { Kind = JsonKind.Object, Object = map };
                    return true;
                }

                while (true)
                {
                    Skip();
                    string key;
                    if (!TryParseString(out key) || map.ContainsKey(key))
                    {
                        return false;
                    }

                    Skip();
                    if (!Eat(':'))
                    {
                        return false;
                    }

                    JsonNode child;
                    if (!TryParseValue(depth + 1, out child))
                    {
                        return false;
                    }

                    map.Add(key, child);
                    Skip();
                    if (Peek('}'))
                    {
                        _index++;
                        node = new JsonNode { Kind = JsonKind.Object, Object = map };
                        return true;
                    }

                    if (!Eat(','))
                    {
                        return false;
                    }
                }
            }

            private bool TryParseArray(int depth, out JsonNode node)
            {
                node = null;
                if (!Eat('['))
                {
                    return false;
                }

                var list = new List<JsonNode>();
                Skip();
                if (Peek(']'))
                {
                    _index++;
                    node = new JsonNode { Kind = JsonKind.Array, Array = list };
                    return true;
                }

                while (true)
                {
                    JsonNode child;
                    if (!TryParseValue(depth + 1, out child))
                    {
                        return false;
                    }

                    list.Add(child);
                    Skip();
                    if (Peek(']'))
                    {
                        _index++;
                        node = new JsonNode { Kind = JsonKind.Array, Array = list };
                        return true;
                    }

                    if (!Eat(','))
                    {
                        return false;
                    }
                }
            }

            private bool TryParseBool(out JsonNode node)
            {
                node = null;
                if (Match("true"))
                {
                    node = new JsonNode { Kind = JsonKind.Bool, Bool = true };
                    return true;
                }

                if (Match("false"))
                {
                    node = new JsonNode { Kind = JsonKind.Bool, Bool = false };
                    return true;
                }

                return false;
            }

            private bool TryParseNull(out JsonNode node)
            {
                node = null;
                if (!Match("null"))
                {
                    return false;
                }

                node = new JsonNode { Kind = JsonKind.Null };
                return true;
            }

            private bool TryParseNumber(out JsonNode node)
            {
                node = null;
                var start = _index;
                if (Peek('-'))
                {
                    _index++;
                }

                if (_index >= _json.Length || !IsDigit(_json[_index]))
                {
                    return false;
                }

                if (_json[_index] == '0')
                {
                    _index++;
                }
                else
                {
                    while (_index < _json.Length && IsDigit(_json[_index]))
                    {
                        _index++;
                    }
                }

                if (_index < _json.Length && _json[_index] == '.')
                {
                    _index++;
                    if (_index >= _json.Length || !IsDigit(_json[_index]))
                    {
                        return false;
                    }

                    while (_index < _json.Length && IsDigit(_json[_index]))
                    {
                        _index++;
                    }
                }

                if (_index < _json.Length && (_json[_index] == 'e' || _json[_index] == 'E'))
                {
                    _index++;
                    if (_index < _json.Length && (_json[_index] == '+' || _json[_index] == '-'))
                    {
                        _index++;
                    }

                    if (_index >= _json.Length || !IsDigit(_json[_index]))
                    {
                        return false;
                    }

                    while (_index < _json.Length && IsDigit(_json[_index]))
                    {
                        _index++;
                    }
                }

                node = new JsonNode
                {
                    Kind = JsonKind.Number,
                    Number = _json.Substring(start, _index - start),
                };
                return true;
            }

            private bool TryParseString(out string text)
            {
                text = null;
                if (!Eat('"'))
                {
                    return false;
                }

                var builder = new StringBuilder();
                while (_index < _json.Length)
                {
                    var c = _json[_index++];
                    if (c == '"')
                    {
                        text = builder.ToString();
                        return true;
                    }

                    if (c == '\\')
                    {
                        if (_index >= _json.Length)
                        {
                            return false;
                        }

                        var escaped = _json[_index++];
                        switch (escaped)
                        {
                            case '"':
                            case '\\':
                            case '/':
                                builder.Append(escaped);
                                break;
                            case 'b':
                                builder.Append('\b');
                                break;
                            case 'f':
                                builder.Append('\f');
                                break;
                            case 'n':
                                builder.Append('\n');
                                break;
                            case 'r':
                                builder.Append('\r');
                                break;
                            case 't':
                                builder.Append('\t');
                                break;
                            case 'u':
                                if (_index + 4 > _json.Length)
                                {
                                    return false;
                                }

                                int code;
                                if (!int.TryParse(_json.Substring(_index, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out code))
                                {
                                    return false;
                                }

                                builder.Append((char)code);
                                _index += 4;
                                break;
                            default:
                                return false;
                        }
                    }
                    else if (c < 0x20)
                    {
                        return false;
                    }
                    else
                    {
                        builder.Append(c);
                    }
                }

                return false;
            }

            private void Skip()
            {
                while (_index < _json.Length && char.IsWhiteSpace(_json[_index]))
                {
                    _index++;
                }
            }

            private bool Eat(char expected)
            {
                Skip();
                if (_index >= _json.Length || _json[_index] != expected)
                {
                    return false;
                }

                _index++;
                return true;
            }

            private bool Peek(char expected)
            {
                return _index < _json.Length && _json[_index] == expected;
            }

            private bool Match(string token)
            {
                if (_index + token.Length > _json.Length)
                {
                    return false;
                }

                if (string.CompareOrdinal(_json, _index, token, 0, token.Length) != 0)
                {
                    return false;
                }

                _index += token.Length;
                return true;
            }

            private static bool IsDigit(char c)
            {
                return c >= '0' && c <= '9';
            }
        }
    }

    public static class SliceTables
    {
        public static bool TryParse(
            string towerJson,
            string enemyJson,
            string levelJson,
            string expectedLevelId,
            out SliceBattleContent content,
            out string error)
        {
            content = null;
            TowerDefinition tower;
            EnemyDefinition enemy;
            LevelDefinition level;
            if (!TryParseTower(towerJson, out tower, out error)
                || !TryParseEnemy(enemyJson, out enemy, out error)
                || !TryParseLevel(levelJson, out level, out error))
            {
                return false;
            }

            if (tower.Id != SliceRules.SliceTowerId)
            {
                error = "M1 切片只接受 tower_jin，已保留原文件";
                return false;
            }

            if (tower.Element != "jin")
            {
                error = "tower_jin 的 element 必须是 jin，已保留原文件";
                return false;
            }

            if (enemy.Id != SliceRules.SliceEnemyId)
            {
                error = "M1 切片只接受 enemy_dangkang，已保留原文件";
                return false;
            }

            if (level.Id != expectedLevelId)
            {
                error = "关卡 id 与切片不一致，已保留原文件";
                return false;
            }

            for (var w = 0; w < level.Waves.Count; w++)
            {
                var spawns = level.Waves[w].Spawns;
                for (var s = 0; s < spawns.Count; s++)
                {
                    if (spawns[s].EnemyId != enemy.Id)
                    {
                        error = "波次引用了未加载的敌人 " + spawns[s].EnemyId + "，已保留原文件";
                        return false;
                    }
                }
            }

            content = new SliceBattleContent
            {
                Tower = tower,
                Enemy = enemy,
                Level = level,
            };
            error = null;
            return true;
        }

        public static bool TryParseTower(string json, out TowerDefinition tower, out string error)
        {
            tower = null;
            JsonNode root;
            if (!TryObject(json, SliceRules.TowerSchema, out root, out error))
            {
                return false;
            }

            var map = root.Object;
            string id;
            string displayName;
            string element;
            if (!ReadString(map, "id", out id, out error)
                || !ReadString(map, "displayName", out displayName, out error)
                || !ReadElement(map, "element", false, out element, out error))
            {
                return false;
            }

            JsonNode economy;
            JsonNode combat;
            JsonNode merge;
            if (!ReadObject(map, "economy", out economy, out error)
                || !ReadObject(map, "combat", out combat, out error)
                || !ReadObject(map, "merge", out merge, out error))
            {
                return false;
            }

            int buildCost;
            if (!ReadInt(economy.Object, "buildCost", out buildCost, out error) || buildCost < 0)
            {
                error = error ?? "buildCost 无法识别，已保留原文件";
                return false;
            }

            JsonNode upgrades;
            if (!Require(economy.Object, "upgradeCosts", out upgrades, out error) || upgrades.Kind != JsonKind.Array)
            {
                error = "upgradeCosts 无法识别，已保留原文件";
                return false;
            }

            for (var i = 0; i < upgrades.Array.Count; i++)
            {
                int cost;
                if (!upgrades.Array[i].TryGetInt(out cost) || cost < 0)
                {
                    error = "upgradeCosts 无法识别，已保留原文件";
                    return false;
                }
            }

            int damage;
            double range;
            int interval;
            string priority;
            if (!ReadInt(combat.Object, "damage", out damage, out error) || damage <= 0)
            {
                error = error ?? "damage 无法识别，已保留原文件";
                return false;
            }

            if (!ReadDouble(combat.Object, "range", out range, out error) || range <= 0)
            {
                error = error ?? "range 无法识别，已保留原文件";
                return false;
            }

            if (!ReadInt(combat.Object, "attackIntervalTicks", out interval, out error) || interval < 1)
            {
                error = error ?? "attackIntervalTicks 无法识别，已保留原文件";
                return false;
            }

            if (!ReadString(combat.Object, "targetPriority", out priority, out error))
            {
                return false;
            }

            if (priority != SliceRules.TargetFirstAlongPath)
            {
                error = "M1 只实现 first_along_path，已保留原文件";
                return false;
            }

            bool mergeEnabled;
            if (!ReadBool(merge.Object, "enabled", out mergeEnabled, out error))
            {
                return false;
            }

            if (mergeEnabled)
            {
                error = "M1 不启用合成，已保留原文件";
                return false;
            }

            tower = new TowerDefinition
            {
                Id = id,
                DisplayName = displayName,
                Element = element,
                BuildCost = buildCost,
                Damage = damage,
                Range = range,
                AttackIntervalTicks = interval,
                TargetPriority = priority,
                MergeEnabled = false,
            };
            error = null;
            return true;
        }

        public static bool TryParseEnemy(string json, out EnemyDefinition enemy, out string error)
        {
            enemy = null;
            JsonNode root;
            if (!TryObject(json, SliceRules.EnemySchema, out root, out error))
            {
                return false;
            }

            var map = root.Object;
            string id;
            string displayName;
            string element;
            if (!ReadString(map, "id", out id, out error)
                || !ReadString(map, "displayName", out displayName, out error)
                || !ReadElement(map, "element", true, out element, out error))
            {
                return false;
            }

            JsonNode combat;
            JsonNode reward;
            if (!ReadObject(map, "combat", out combat, out error) || !ReadObject(map, "reward", out reward, out error))
            {
                return false;
            }

            int maxHp;
            double speed;
            int leakDamage;
            if (!ReadInt(combat.Object, "maxHp", out maxHp, out error) || maxHp <= 0)
            {
                error = error ?? "maxHp 无法识别，已保留原文件";
                return false;
            }

            if (!ReadDouble(combat.Object, "speed", out speed, out error) || speed <= 0)
            {
                error = error ?? "speed 无法识别，已保留原文件";
                return false;
            }

            if (!ReadInt(combat.Object, "leakDamage", out leakDamage, out error) || leakDamage < 0)
            {
                error = error ?? "leakDamage 无法识别，已保留原文件";
                return false;
            }

            string currencyId;
            int amount;
            if (!ReadString(reward.Object, "currencyId", out currencyId, out error))
            {
                return false;
            }

            if (!ReadInt(reward.Object, "amount", out amount, out error) || amount < 0)
            {
                error = error ?? "reward.amount 无法识别，已保留原文件";
                return false;
            }

            enemy = new EnemyDefinition
            {
                Id = id,
                DisplayName = displayName,
                Element = element,
                MaxHp = maxHp,
                Speed = speed,
                LeakDamage = leakDamage,
                RewardCurrencyId = currencyId,
                RewardAmount = amount,
            };
            error = null;
            return true;
        }

        public static bool TryParseLevel(string json, out LevelDefinition level, out string error)
        {
            level = null;
            JsonNode root;
            if (!TryObject(json, SliceRules.LevelSchema, out root, out error))
            {
                return false;
            }

            var map = root.Object;
            string id;
            string displayName;
            string pathId;
            string space;
            if (!ReadString(map, "id", out id, out error)
                || !ReadString(map, "displayName", out displayName, out error)
                || !ReadString(map, "pathId", out pathId, out error)
                || !ReadString(map, "space", out space, out error))
            {
                return false;
            }

            double maxX;
            double maxY;
            if (!SliceRules.TryGetBounds(space, out maxX, out maxY, out error))
            {
                return false;
            }

            List<WaypointDefinition> waypoints;
            List<WaveDefinition> waves;
            List<BuildCellDefinition> cells;
            if (!ReadWaypoints(map, out waypoints, out error)
                || !ReadWaves(map, out waves, out error)
                || !ReadCells(map, out cells, out error))
            {
                return false;
            }

            if (!WithinSpace(space, maxX, maxY, waypoints, cells, out error))
            {
                return false;
            }

            JsonNode outcome;
            if (!ReadObject(map, "outcome", out outcome, out error))
            {
                return false;
            }

            string winRule;
            string loseRule;
            int loseLeakCount;
            if (!ReadString(outcome.Object, "win", out winRule, out error))
            {
                return false;
            }

            if (winRule != SliceRules.WinAllWavesCleared)
            {
                error = "M1 只实现 all_waves_cleared，已保留原文件";
                return false;
            }

            if (!ReadString(outcome.Object, "lose", out loseRule, out error))
            {
                return false;
            }

            if (loseRule != SliceRules.LoseLeakCount)
            {
                error = "失败规则尚未实现：" + loseRule + "。M1 切片使用 leak_count，已保留原文件";
                return false;
            }

            if (!ReadInt(outcome.Object, "loseLeakCount", out loseLeakCount, out error) || loseLeakCount < 1)
            {
                error = error ?? "loseLeakCount 无法识别，已保留原文件";
                return false;
            }

            LevelEconomyDefinition economy;
            if (!ReadEconomy(map, out economy, out error))
            {
                return false;
            }

            level = new LevelDefinition
            {
                Id = id,
                DisplayName = displayName,
                PathId = pathId,
                Space = space,
                Waypoints = waypoints,
                Waves = waves,
                BuildCells = cells,
                Economy = economy,
                WinRule = winRule,
                LoseRule = loseRule,
                LoseLeakCount = loseLeakCount,
            };
            error = null;
            return true;
        }

        private static bool TryObject(string json, string schemaId, out JsonNode root, out string error)
        {
            root = null;
            if (!JsonReader.TryParse(json, out root, out error) || root.Kind != JsonKind.Object)
            {
                error = error ?? "JSON 无法解析，已保留原文件";
                root = null;
                return false;
            }

            string schema;
            int version;
            if (!ReadString(root.Object, "schema", out schema, out error))
            {
                return false;
            }

            if (schema != schemaId)
            {
                error = "schema 无法识别，已保留原文件";
                return false;
            }

            if (!ReadInt(root.Object, "schemaVersion", out version, out error))
            {
                return false;
            }

            if (version != SliceRules.SchemaVersion)
            {
                error = "schemaVersion 无法识别，已保留原文件";
                return false;
            }

            if (!AcceptPlayableSlice(root.Object, out error))
            {
                return false;
            }

            return true;
        }

        private static bool AcceptPlayableSlice(Dictionary<string, JsonNode> map, out string error)
        {
            JsonNode placeholder;
            if (map.TryGetValue("placeholder", out placeholder) && placeholder != null)
            {
                if (placeholder.Kind != JsonKind.Bool)
                {
                    error = "placeholder 无法识别，已保留原文件";
                    return false;
                }

                if (placeholder.Bool)
                {
                    error = "placeholder 表不能进入战斗，已保留原文件";
                    return false;
                }
            }

            string slice;
            if (!ReadString(map, "slice", out slice, out error))
            {
                return false;
            }

            if (!SliceRules.IsAcceptedSlice(slice))
            {
                error = "slice 无法识别，已保留原文件";
                return false;
            }

            error = null;
            return true;
        }

        private static bool ReadWaypoints(Dictionary<string, JsonNode> map, out List<WaypointDefinition> waypoints, out string error)
        {
            waypoints = null;
            JsonNode node;
            if (!Require(map, "waypoints", out node, out error) || node.Kind != JsonKind.Array || node.Array.Count < 2)
            {
                error = "waypoints 无法识别，已保留原文件";
                return false;
            }

            var list = new List<WaypointDefinition>();
            var seen = new HashSet<string>();
            for (var i = 0; i < node.Array.Count; i++)
            {
                var item = node.Array[i];
                if (item.Kind != JsonKind.Object)
                {
                    error = "waypoints 无法识别，已保留原文件";
                    return false;
                }

                string id;
                double x;
                double y;
                if (!ReadString(item.Object, "id", out id, out error)
                    || !ReadDouble(item.Object, "x", out x, out error)
                    || !ReadDouble(item.Object, "y", out y, out error))
                {
                    error = error ?? "waypoints 无法识别，已保留原文件";
                    return false;
                }

                if (!seen.Add(id))
                {
                    error = "waypoints id 重复，已保留原文件";
                    return false;
                }

                list.Add(new WaypointDefinition { Id = id, X = x, Y = y });
            }

            waypoints = list;
            error = null;
            return true;
        }

        private static bool ReadWaves(Dictionary<string, JsonNode> map, out List<WaveDefinition> waves, out string error)
        {
            waves = null;
            JsonNode node;
            if (!Require(map, "waves", out node, out error) || node.Kind != JsonKind.Array || node.Array.Count < 1)
            {
                error = "waves 无法识别，已保留原文件";
                return false;
            }

            var list = new List<WaveDefinition>();
            var seen = new HashSet<string>();
            for (var i = 0; i < node.Array.Count; i++)
            {
                var item = node.Array[i];
                if (item.Kind != JsonKind.Object)
                {
                    error = "waves 无法识别，已保留原文件";
                    return false;
                }

                string id;
                if (!ReadString(item.Object, "id", out id, out error))
                {
                    return false;
                }

                if (!seen.Add(id))
                {
                    error = "waves id 重复，已保留原文件";
                    return false;
                }

                JsonNode spawnsNode;
                if (!Require(item.Object, "spawns", out spawnsNode, out error) || spawnsNode.Kind != JsonKind.Array || spawnsNode.Array.Count < 1)
                {
                    error = "spawns 无法识别，已保留原文件";
                    return false;
                }

                var spawns = new List<SpawnDefinition>();
                for (var s = 0; s < spawnsNode.Array.Count; s++)
                {
                    var spawn = spawnsNode.Array[s];
                    if (spawn.Kind != JsonKind.Object)
                    {
                        error = "spawns 无法识别，已保留原文件";
                        return false;
                    }

                    string enemyId;
                    int count;
                    int interval;
                    if (!ReadString(spawn.Object, "enemyId", out enemyId, out error))
                    {
                        return false;
                    }

                    if (!ReadInt(spawn.Object, "count", out count, out error) || count < 1)
                    {
                        error = error ?? "count 无法识别，已保留原文件";
                        return false;
                    }

                    if (!ReadInt(spawn.Object, "intervalTicks", out interval, out error) || interval < 1)
                    {
                        error = error ?? "intervalTicks 无法识别，已保留原文件";
                        return false;
                    }

                    double hpMultiplier = 1.0;
                    JsonNode hpNode;
                    if (spawn.Object.TryGetValue("hpMultiplier", out hpNode))
                    {
                        if (hpNode == null || !hpNode.TryGetDouble(out hpMultiplier) || hpMultiplier <= 0)
                        {
                            error = "hpMultiplier 无法识别，已保留原文件";
                            return false;
                        }

                        if (double.IsNaN(hpMultiplier) || double.IsInfinity(hpMultiplier))
                        {
                            error = "hpMultiplier 无法识别，已保留原文件";
                            return false;
                        }
                    }

                    spawns.Add(new SpawnDefinition
                    {
                        EnemyId = enemyId,
                        Count = count,
                        IntervalTicks = interval,
                        HpMultiplier = hpMultiplier,
                    });
                }

                list.Add(new WaveDefinition { Id = id, Spawns = spawns });
            }

            waves = list;
            error = null;
            return true;
        }

        private static bool ReadEconomy(Dictionary<string, JsonNode> map, out LevelEconomyDefinition economy, out string error)
        {
            economy = null;
            JsonNode node;
            if (!ReadObject(map, "economy", out node, out error))
            {
                return false;
            }

            string currencyId;
            int starting;
            int waveBase;
            int perWave;
            if (!ReadString(node.Object, "currencyId", out currencyId, out error))
            {
                return false;
            }

            if (!ReadInt(node.Object, "startingAmount", out starting, out error) || starting < 0)
            {
                error = error ?? "startingAmount 无法识别，已保留原文件";
                return false;
            }

            if (!ReadInt(node.Object, "waveClearBase", out waveBase, out error) || waveBase < 0)
            {
                error = error ?? "waveClearBase 无法识别，已保留原文件";
                return false;
            }

            if (!ReadInt(node.Object, "waveClearPerWaveIndex", out perWave, out error) || perWave < 0)
            {
                error = error ?? "waveClearPerWaveIndex 无法识别，已保留原文件";
                return false;
            }

            economy = new LevelEconomyDefinition
            {
                CurrencyId = currencyId,
                StartingAmount = starting,
                WaveClearBase = waveBase,
                WaveClearPerWaveIndex = perWave,
            };
            error = null;
            return true;
        }

        private static bool ReadCells(Dictionary<string, JsonNode> map, out List<BuildCellDefinition> cells, out string error)
        {
            cells = null;
            JsonNode node;
            if (!Require(map, "buildCells", out node, out error) || node.Kind != JsonKind.Array || node.Array.Count < 1)
            {
                error = "缺少 buildCells。M1 需要至少一个可建造格，已保留原文件";
                return false;
            }

            var list = new List<BuildCellDefinition>();
            var seen = new HashSet<string>();
            for (var i = 0; i < node.Array.Count; i++)
            {
                var item = node.Array[i];
                if (item.Kind != JsonKind.Object)
                {
                    error = "buildCells 无法识别，已保留原文件";
                    return false;
                }

                string id;
                double x;
                double y;
                if (!ReadString(item.Object, "id", out id, out error)
                    || !ReadDouble(item.Object, "x", out x, out error)
                    || !ReadDouble(item.Object, "y", out y, out error))
                {
                    error = error ?? "buildCells 无法识别，已保留原文件";
                    return false;
                }

                if (!seen.Add(id))
                {
                    error = "buildCells id 重复，已保留原文件";
                    return false;
                }

                list.Add(new BuildCellDefinition { Id = id, X = x, Y = y });
            }

            cells = list;
            error = null;
            return true;
        }

        private static bool WithinSpace(
            string space,
            double maxX,
            double maxY,
            List<WaypointDefinition> waypoints,
            List<BuildCellDefinition> cells,
            out string error)
        {
            const double Epsilon = 1e-9;
            for (var i = 0; i < waypoints.Count; i++)
            {
                var point = waypoints[i];
                if (!Inside(point.X, point.Y, maxX, maxY, Epsilon))
                {
                    error = "坐标超出 " + space + "：" + point.Id + "，已保留原文件";
                    return false;
                }
            }

            for (var i = 0; i < cells.Count; i++)
            {
                var cell = cells[i];
                if (!Inside(cell.X, cell.Y, maxX, maxY, Epsilon))
                {
                    error = "坐标超出 " + space + "：" + cell.Id + "，已保留原文件";
                    return false;
                }
            }

            error = null;
            return true;
        }

        private static bool Inside(double x, double y, double maxX, double maxY, double epsilon)
        {
            if (double.IsNaN(x) || double.IsInfinity(x) || double.IsNaN(y) || double.IsInfinity(y))
            {
                return false;
            }

            return x >= -epsilon && y >= -epsilon && x <= maxX + epsilon && y <= maxY + epsilon;
        }

        private static bool ReadElement(Dictionary<string, JsonNode> map, string name, bool allowNull, out string element, out string error)
        {
            element = null;
            JsonNode node;
            if (!Require(map, name, out node, out error))
            {
                return false;
            }

            if (node.Kind == JsonKind.Null)
            {
                if (!allowNull)
                {
                    error = name + " 无法识别，已保留原文件";
                    return false;
                }

                error = null;
                return true;
            }

            if (node.Kind != JsonKind.String)
            {
                error = name + " 无法识别，已保留原文件";
                return false;
            }

            if (!IsElementId(node.String))
            {
                error = name + " 无法识别，已保留原文件";
                return false;
            }

            element = node.String;
            error = null;
            return true;
        }

        private static bool IsElementId(string id)
        {
            return id == "jin" || id == "mu" || id == "shui" || id == "huo" || id == "tu";
        }

        private static bool ReadObject(Dictionary<string, JsonNode> map, string name, out JsonNode node, out string error)
        {
            if (!Require(map, name, out node, out error) || node.Kind != JsonKind.Object)
            {
                error = name + " 无法识别，已保留原文件";
                node = null;
                return false;
            }

            error = null;
            return true;
        }

        private static bool ReadString(Dictionary<string, JsonNode> map, string name, out string value, out string error)
        {
            value = null;
            JsonNode node;
            if (!Require(map, name, out node, out error) || node.Kind != JsonKind.String || string.IsNullOrEmpty(node.String))
            {
                error = name + " 无法识别，已保留原文件";
                return false;
            }

            value = node.String;
            error = null;
            return true;
        }

        private static bool ReadInt(Dictionary<string, JsonNode> map, string name, out int value, out string error)
        {
            value = 0;
            JsonNode node;
            if (!Require(map, name, out node, out error) || !node.TryGetInt(out value))
            {
                error = name + " 无法识别，已保留原文件";
                return false;
            }

            error = null;
            return true;
        }

        private static bool ReadDouble(Dictionary<string, JsonNode> map, string name, out double value, out string error)
        {
            value = 0;
            JsonNode node;
            if (!Require(map, name, out node, out error) || !node.TryGetDouble(out value))
            {
                error = name + " 无法识别，已保留原文件";
                return false;
            }

            error = null;
            return true;
        }

        private static bool ReadBool(Dictionary<string, JsonNode> map, string name, out bool value, out string error)
        {
            value = false;
            JsonNode node;
            if (!Require(map, name, out node, out error) || node.Kind != JsonKind.Bool)
            {
                error = name + " 无法识别，已保留原文件";
                return false;
            }

            value = node.Bool;
            error = null;
            return true;
        }

        private static bool Require(Dictionary<string, JsonNode> map, string name, out JsonNode node, out string error)
        {
            if (map != null && map.TryGetValue(name, out node) && node != null)
            {
                error = null;
                return true;
            }

            node = null;
            error = "缺少字段 " + name + "，已保留原文件";
            return false;
        }
    }
}
