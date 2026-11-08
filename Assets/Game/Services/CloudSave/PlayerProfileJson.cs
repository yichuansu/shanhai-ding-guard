using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace ShanhaiDingGuard.Services.CloudSave
{
    public static class PlayerProfileJson
    {
        public static bool TryRead(string json, out PlayerProfile profile, out string error)
        {
            profile = null;
            error = null;
            JsonValue root;
            if (!JsonValue.TryParse(json, out root, out error) || root.Type != JsonKind.Object)
            {
                error = error ?? "JSON 无法解析，已保留原文件";
                return false;
            }

            JsonValue schema;
            JsonValue version;
            JsonValue accountId;
            JsonValue currencies;
            JsonValue levelProgress;
            JsonValue unlocks;
            JsonValue settings;
            if (!root.Object.TryGetValue("schema", out schema)
                || !root.Object.TryGetValue("schemaVersion", out version)
                || !root.Object.TryGetValue("accountId", out accountId)
                || !root.Object.TryGetValue("currencies", out currencies)
                || !root.Object.TryGetValue("levelProgress", out levelProgress)
                || !root.Object.TryGetValue("shanhaijingUnlocks", out unlocks)
                || !root.Object.TryGetValue("settings", out settings))
            {
                error = "档案缺少字段，已保留原文件";
                return false;
            }

            if (schema.Type != JsonKind.String || schema.String != PlayerProfile.SchemaId)
            {
                error = "schema 无法识别，已保留原文件";
                return false;
            }

            int schemaVersion;
            if (!version.TryGetInt(out schemaVersion))
            {
                error = "schemaVersion 无法识别，已保留原文件";
                return false;
            }

            if (schemaVersion != PlayerProfile.CurrentSchemaVersion)
            {
                error = "schemaVersion 无法识别，已保留原文件";
                return false;
            }

            if (currencies.Type != JsonKind.Object || levelProgress.Type != JsonKind.Object || unlocks.Type != JsonKind.Array)
            {
                error = "档案字段类型不符，已保留原文件";
                return false;
            }

            if (settings.Type != JsonKind.Object)
            {
                error = "settings 无法识别，已保留原文件";
                return false;
            }

            string account = string.Empty;
            if (accountId.Type == JsonKind.String)
            {
                account = accountId.String;
            }
            else if (accountId.Type != JsonKind.Null)
            {
                error = "accountId 无法识别，已保留原文件";
                return false;
            }

            var parsedCurrencies = new Dictionary<string, int>();
            foreach (var pair in currencies.Object)
            {
                int amount;
                if (!pair.Value.TryGetInt(out amount))
                {
                    error = "currencies 无法识别，已保留原文件";
                    return false;
                }

                parsedCurrencies.Add(pair.Key, amount);
            }

            var parsedUnlocks = new List<string>();
            for (var i = 0; i < unlocks.Array.Count; i++)
            {
                var entry = unlocks.Array[i];
                if (entry.Type != JsonKind.String)
                {
                    error = "shanhaijingUnlocks 无法识别，已保留原文件";
                    return false;
                }

                parsedUnlocks.Add(entry.String);
            }

            JsonValue speedValue;
            int speed;
            if (!settings.Object.TryGetValue("simulationSpeed", out speedValue) || !speedValue.TryGetInt(out speed))
            {
                error = "simulationSpeed 无法识别，已保留原文件";
                return false;
            }

            string levelJson;
            if (!levelProgress.TryWrite(out levelJson))
            {
                error = "levelProgress 无法识别，已保留原文件";
                return false;
            }

            profile = new PlayerProfile
            {
                Schema = PlayerProfile.SchemaId,
                SchemaVersion = schemaVersion,
                AccountId = account,
                Currencies = parsedCurrencies,
                LevelProgressJson = levelJson,
                ShanhaijingUnlocks = parsedUnlocks,
                SimulationSpeed = speed,
            };
            return true;
        }

        public static bool TryWrite(PlayerProfile profile, out string json, out string error)
        {
            json = null;
            error = null;
            if (profile == null)
            {
                error = "档案为空";
                return false;
            }

            if (profile.Schema != PlayerProfile.SchemaId || profile.SchemaVersion != PlayerProfile.CurrentSchemaVersion)
            {
                error = "schemaVersion 无法识别，已保留原文件";
                return false;
            }

            JsonValue levelProgress;
            if (!JsonValue.TryParse(string.IsNullOrEmpty(profile.LevelProgressJson) ? "{}" : profile.LevelProgressJson, out levelProgress, out error)
                || levelProgress.Type != JsonKind.Object)
            {
                error = "levelProgress 无法识别，已保留原文件";
                return false;
            }

            var builder = new StringBuilder();
            builder.Append("{\n");
            AppendStringField(builder, "schema", PlayerProfile.SchemaId, 1);
            builder.Append(",\n");
            AppendRawField(builder, "schemaVersion", profile.SchemaVersion.ToString(CultureInfo.InvariantCulture), 1);
            builder.Append(",\n");
            AppendStringField(builder, "accountId", profile.AccountId ?? string.Empty, 1);
            builder.Append(",\n");
            builder.Append("  \"currencies\": ");
            AppendCurrencies(builder, profile.Currencies);
            builder.Append(",\n");
            builder.Append("  \"levelProgress\": ");
            string levelJson;
            if (!levelProgress.TryWrite(out levelJson))
            {
                error = "levelProgress 无法识别，已保留原文件";
                return false;
            }

            builder.Append(levelJson);
            builder.Append(",\n");
            builder.Append("  \"shanhaijingUnlocks\": ");
            AppendUnlocks(builder, profile.ShanhaijingUnlocks);
            builder.Append(",\n");
            builder.Append("  \"settings\": {\n");
            AppendRawField(builder, "simulationSpeed", profile.SimulationSpeed.ToString(CultureInfo.InvariantCulture), 2);
            builder.Append("\n  }\n}");
            json = builder.ToString();
            return true;
        }

        private static void AppendCurrencies(StringBuilder builder, Dictionary<string, int> currencies)
        {
            builder.Append('{');
            if (currencies == null || currencies.Count == 0)
            {
                builder.Append('}');
                return;
            }

            var keys = new List<string>(currencies.Keys);
            keys.Sort(StringComparer.Ordinal);
            for (var i = 0; i < keys.Count; i++)
            {
                if (i > 0)
                {
                    builder.Append(',');
                }

                builder.Append(Escape(keys[i]));
                builder.Append(':');
                builder.Append(currencies[keys[i]].ToString(CultureInfo.InvariantCulture));
            }

            builder.Append('}');
        }

        private static void AppendUnlocks(StringBuilder builder, List<string> unlocks)
        {
            builder.Append('[');
            if (unlocks != null)
            {
                for (var i = 0; i < unlocks.Count; i++)
                {
                    if (i > 0)
                    {
                        builder.Append(',');
                    }

                    builder.Append(Escape(unlocks[i] ?? string.Empty));
                }
            }

            builder.Append(']');
        }

        private static void AppendStringField(StringBuilder builder, string name, string value, int indent)
        {
            AppendIndent(builder, indent);
            builder.Append(Escape(name));
            builder.Append(": ");
            builder.Append(Escape(value));
        }

        private static void AppendRawField(StringBuilder builder, string name, string raw, int indent)
        {
            AppendIndent(builder, indent);
            builder.Append(Escape(name));
            builder.Append(": ");
            builder.Append(raw);
        }

        private static void AppendIndent(StringBuilder builder, int indent)
        {
            for (var i = 0; i < indent; i++)
            {
                builder.Append("  ");
            }
        }

        internal static string Escape(string value)
        {
            var builder = new StringBuilder(value.Length + 2);
            builder.Append('"');
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

            builder.Append('"');
            return builder.ToString();
        }
    }

    internal enum JsonKind
    {
        Null,
        Bool,
        Number,
        String,
        Object,
        Array,
    }

    internal sealed class JsonValue
    {
        public JsonKind Type;
        public bool Bool;
        public string Number;
        public string String;
        public Dictionary<string, JsonValue> Object;
        public List<JsonValue> Array;

        public bool TryGetInt(out int value)
        {
            value = 0;
            if (Type != JsonKind.Number || string.IsNullOrEmpty(Number))
            {
                return false;
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

        public static bool TryParse(string json, out JsonValue value, out string error)
        {
            value = null;
            error = null;
            if (string.IsNullOrEmpty(json))
            {
                error = "JSON 无法解析，已保留原文件";
                return false;
            }

            var parser = new Parser(json);
            if (!parser.TryParseValue(out value) || !parser.End())
            {
                error = "JSON 无法解析，已保留原文件";
                value = null;
                return false;
            }

            return true;
        }

        public bool TryWrite(out string json)
        {
            var builder = new StringBuilder();
            if (!TryWriteTo(builder, 0))
            {
                json = null;
                return false;
            }

            json = builder.ToString();
            return true;
        }

        private bool TryWriteTo(StringBuilder builder, int depth)
        {
            if (depth > 32)
            {
                return false;
            }

            switch (Type)
            {
                case JsonKind.Null:
                    builder.Append("null");
                    return true;
                case JsonKind.Bool:
                    builder.Append(Bool ? "true" : "false");
                    return true;
                case JsonKind.Number:
                    builder.Append(Number);
                    return true;
                case JsonKind.String:
                    builder.Append(PlayerProfileJson.Escape(String ?? string.Empty));
                    return true;
                case JsonKind.Array:
                    builder.Append('[');
                    for (var i = 0; i < Array.Count; i++)
                    {
                        if (i > 0)
                        {
                            builder.Append(',');
                        }

                        if (!Array[i].TryWriteTo(builder, depth + 1))
                        {
                            return false;
                        }
                    }

                    builder.Append(']');
                    return true;
                case JsonKind.Object:
                    builder.Append('{');
                    var first = true;
                    foreach (var pair in Object)
                    {
                        if (!first)
                        {
                            builder.Append(',');
                        }

                        first = false;
                        builder.Append(PlayerProfileJson.Escape(pair.Key));
                        builder.Append(':');
                        if (!pair.Value.TryWriteTo(builder, depth + 1))
                        {
                            return false;
                        }
                    }

                    builder.Append('}');
                    return true;
                default:
                    return false;
            }
        }

        private sealed class Parser
        {
            private readonly string _json;
            private int _index;

            public Parser(string json)
            {
                _json = json;
            }

            public bool End()
            {
                Skip();
                return _index >= _json.Length;
            }

            public bool TryParseValue(out JsonValue value)
            {
                value = null;
                Skip();
                if (_index >= _json.Length)
                {
                    return false;
                }

                var c = _json[_index];
                if (c == '{')
                {
                    return TryParseObject(out value);
                }

                if (c == '[')
                {
                    return TryParseArray(out value);
                }

                if (c == '"')
                {
                    string text;
                    if (!TryParseString(out text))
                    {
                        return false;
                    }

                    value = new JsonValue { Type = JsonKind.String, String = text };
                    return true;
                }

                if (c == 't' || c == 'f')
                {
                    return TryParseBool(out value);
                }

                if (c == 'n')
                {
                    return TryParseNull(out value);
                }

                return TryParseNumber(out value);
            }

            private bool TryParseObject(out JsonValue value)
            {
                value = null;
                if (!Eat('{'))
                {
                    return false;
                }

                var map = new Dictionary<string, JsonValue>();
                Skip();
                if (Peek('}'))
                {
                    _index++;
                    value = new JsonValue { Type = JsonKind.Object, Object = map };
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

                    JsonValue child;
                    if (!TryParseValue(out child))
                    {
                        return false;
                    }

                    map.Add(key, child);
                    Skip();
                    if (Peek('}'))
                    {
                        _index++;
                        value = new JsonValue { Type = JsonKind.Object, Object = map };
                        return true;
                    }

                    if (!Eat(','))
                    {
                        return false;
                    }
                }
            }

            private bool TryParseArray(out JsonValue value)
            {
                value = null;
                if (!Eat('['))
                {
                    return false;
                }

                var list = new List<JsonValue>();
                Skip();
                if (Peek(']'))
                {
                    _index++;
                    value = new JsonValue { Type = JsonKind.Array, Array = list };
                    return true;
                }

                while (true)
                {
                    JsonValue child;
                    if (!TryParseValue(out child))
                    {
                        return false;
                    }

                    list.Add(child);
                    Skip();
                    if (Peek(']'))
                    {
                        _index++;
                        value = new JsonValue { Type = JsonKind.Array, Array = list };
                        return true;
                    }

                    if (!Eat(','))
                    {
                        return false;
                    }
                }
            }

            private bool TryParseBool(out JsonValue value)
            {
                value = null;
                if (Match("true"))
                {
                    value = new JsonValue { Type = JsonKind.Bool, Bool = true };
                    return true;
                }

                if (Match("false"))
                {
                    value = new JsonValue { Type = JsonKind.Bool, Bool = false };
                    return true;
                }

                return false;
            }

            private bool TryParseNull(out JsonValue value)
            {
                value = null;
                if (!Match("null"))
                {
                    return false;
                }

                value = new JsonValue { Type = JsonKind.Null };
                return true;
            }

            private bool TryParseNumber(out JsonValue value)
            {
                value = null;
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

                if (_index < _json.Length && (_json[_index] == '.' || _json[_index] == 'e' || _json[_index] == 'E'))
                {
                    return false;
                }

                value = new JsonValue
                {
                    Type = JsonKind.Number,
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
}
