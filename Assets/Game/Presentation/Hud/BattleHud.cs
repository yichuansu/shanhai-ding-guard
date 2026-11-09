using System;
using System.Collections.Generic;
using ShanhaiDingGuard.Content;
using ShanhaiDingGuard.Gameplay.CombatSimulation;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.SceneManagement;

namespace ShanhaiDingGuard.Presentation
{
    /// <summary>
    /// M1 战斗桩：开战、放置金塔、胜、负、1x/2x。表现只读快照，不改生命。
    /// 倍速交给 SimClock，不乘进伤害。
    /// </summary>
    public sealed class BattleHud : MonoBehaviour
    {
        public readonly struct BattleFinished
        {
            public BattleFinished(string levelId, bool won, int leakCount)
            {
                LevelId = levelId;
                Won = won;
                LeakCount = leakCount;
            }

            public string LevelId { get; }

            public bool Won { get; }

            public int LeakCount { get; }
        }

        private const float PlayfieldSize = 9f;

        private readonly SimClock _clock = new SimClock();
        private readonly Dictionary<int, Transform> _enemies = new Dictionary<int, Transform>();
        private SliceBattleContent _content;
        private CombatSimulation _sim;
        private string _error = "读取切片表…";
        private bool _started;
        private bool _reported;
        private Transform _viewRoot;
        private Transform _towerMarker;
        private Sprite _pixel;

        public event Action<BattleFinished> Finished;

        private async void Start()
        {
            var loaded = await SliceContentLoader.LoadSliceAsync();
            if (!isActiveAndEnabled)
            {
                return;
            }

            if (!loaded.Success)
            {
                _error = loaded.Error;
                return;
            }

            CombatSimulation sim;
            string error;
            if (!CombatSimulation.TryCreate(loaded.Content, out sim, out error))
            {
                _error = error;
                return;
            }

            _content = loaded.Content;
            _sim = sim;
            _error = null;
            BuildView();
        }

        private void Update()
        {
            if (Pressed(BackRect()) || PressedKey(Key.Escape))
            {
                SceneManager.LoadScene("Hub");
                return;
            }

            if (_sim == null)
            {
                return;
            }

            if (!_started && (Pressed(StartRect()) || PressedKey(Key.Enter) || PressedKey(Key.Space) || PressedKey(Key.NumpadEnter)))
            {
                _started = true;
                _sim.Begin();
            }

            if (Pressed(PlaceRect()) || PressedKey(Key.T))
            {
                PlaceTower();
            }

            if (Pressed(SpeedRect()) || PressedKey(Key.X))
            {
                _clock.ToggleSpeed();
            }

            if (_started && _sim.Phase == BattlePhase.Running)
            {
                var ticks = _clock.ConsumeTicks(Time.deltaTime);
                for (var i = 0; i < ticks; i++)
                {
                    _sim.Tick();
                }
            }

            SyncView();
            ReportIfFinished();
        }

        private void OnGUI()
        {
            DrawButton(StartRect(), _started ? "进行中" : "开战");
            DrawButton(PlaceRect(), TowerPlaced() ? "金塔已放置" : "放置金塔");
            DrawButton(SpeedRect(), "倍速 " + _clock.Speed + "x");
            DrawButton(BackRect(), "回枢纽");

            var style = Style(18, TextAnchor.UpperLeft);
            var status = _error;
            if (_sim != null && _content != null)
            {
                var snapshot = _sim.Snapshot;
                status = _content.Level.DisplayName
                    + "\n"
                    + PhaseLabel(snapshot.Phase)
                    + "  tick "
                    + snapshot.Tick
                    + "  场上 "
                    + snapshot.Enemies.Count
                    + "  漏怪 "
                    + snapshot.LeakCount
                    + "/"
                    + snapshot.LoseLeakCount
                    + " ("
                    + snapshot.LoseRule
                    + ")";
                if (!string.IsNullOrEmpty(snapshot.Note))
                {
                    status += "\n" + snapshot.Note;
                }
            }

            GUI.Label(new Rect(250f, 24f, Screen.width - 280f, 140f), status ?? string.Empty, style);
            GUI.Label(
                new Rect(24f, Screen.height - 88f, Screen.width - 48f, 72f),
                "先放金塔再开战会清完三波并胜利。不放塔直接开战，第一只当康漏出即失败。X 或「倍速」在 1x / 2x 间切换，只加快模拟 tick。T 放置，Enter 开战，Esc 回枢纽。",
                Style(16, TextAnchor.UpperLeft));

            if (_sim != null && (_sim.Phase == BattlePhase.Won || _sim.Phase == BattlePhase.Lost))
            {
                var banner = _sim.Phase == BattlePhase.Won ? "胜利" : "失败";
                var rect = new Rect((Screen.width * 0.5f) - 160f, (Screen.height * 0.5f) - 40f, 320f, 80f);
                GUI.Box(rect, GUIContent.none);
                GUI.Label(rect, banner, Style(40, TextAnchor.MiddleCenter));
            }
        }

        private void PlaceTower()
        {
            if (_sim == null || _content == null || TowerPlaced())
            {
                return;
            }

            _sim.EnqueuePlace(_content.Tower.Id, _content.Level.BuildCells[0].Id);
        }

        private bool TowerPlaced()
        {
            if (_sim == null || _sim.Snapshot == null)
            {
                return false;
            }

            if (_sim.Snapshot.Towers.Count > 0)
            {
                return true;
            }

            for (var i = 0; i < _sim.Snapshot.Cells.Count; i++)
            {
                if (_sim.Snapshot.Cells[i].Queued)
                {
                    return true;
                }
            }

            return false;
        }

        private void ReportIfFinished()
        {
            if (_reported || _sim == null)
            {
                return;
            }

            if (_sim.Phase != BattlePhase.Won && _sim.Phase != BattlePhase.Lost)
            {
                return;
            }

            _reported = true;
            var handler = Finished;
            if (handler != null)
            {
                handler(new BattleFinished(_content.Level.Id, _sim.Phase == BattlePhase.Won, _sim.LeakCount));
            }
        }

        private void BuildView()
        {
            _pixel = Pixel();
            _viewRoot = new GameObject("SliceView").transform;
            var board = CreateSprite("Playfield", new Color(0.1f, 0.12f, 0.14f, 1f), 0);
            board.localScale = new Vector3(PlayfieldSize, PlayfieldSize, 1f);

            var waypoints = _content.Level.Waypoints;
            for (var i = 1; i < waypoints.Count; i++)
            {
                var from = ToWorld(waypoints[i - 1].X, waypoints[i - 1].Y);
                var to = ToWorld(waypoints[i].X, waypoints[i].Y);
                var segment = CreateSprite("Path", new Color(0.93f, 0.84f, 0.55f, 1f), 1);
                var delta = to - from;
                var length = delta.magnitude;
                segment.position = (from + to) * 0.5f;
                if (length > 0.001f)
                {
                    segment.right = delta;
                }

                segment.localScale = new Vector3(length, 0.08f, 1f);
            }

            var exit = waypoints[waypoints.Count - 1];
            var exitMark = CreateSprite("Exit", new Color(0.85f, 0.25f, 0.22f, 1f), 2);
            exitMark.position = ToWorld(exit.X, exit.Y);
            exitMark.localScale = new Vector3(0.28f, 0.28f, 1f);

            var cell = _content.Level.BuildCells[0];
            var cellMark = CreateSprite("BuildCell", new Color(0.95f, 0.78f, 0.28f, 0.35f), 2);
            cellMark.position = ToWorld(cell.X, cell.Y);
            cellMark.localScale = new Vector3(0.55f, 0.55f, 1f);

            _towerMarker = CreateSprite("TowerJin", new Color(0.96f, 0.82f, 0.28f, 1f), 4);
            _towerMarker.gameObject.SetActive(false);
            _towerMarker.localScale = new Vector3(0.42f, 0.42f, 1f);
        }

        private void SyncView()
        {
            if (_sim == null || _viewRoot == null)
            {
                return;
            }

            var snapshot = _sim.Snapshot;
            if (snapshot.Towers.Count > 0)
            {
                var tower = snapshot.Towers[0];
                _towerMarker.gameObject.SetActive(true);
                _towerMarker.position = ToWorld(tower.X, tower.Y);
            }
            else
            {
                var queued = false;
                for (var i = 0; i < snapshot.Cells.Count; i++)
                {
                    if (!snapshot.Cells[i].Queued)
                    {
                        continue;
                    }

                    queued = true;
                    _towerMarker.gameObject.SetActive(true);
                    _towerMarker.position = ToWorld(snapshot.Cells[i].X, snapshot.Cells[i].Y);
                    break;
                }

                if (!queued)
                {
                    _towerMarker.gameObject.SetActive(false);
                }
            }

            var seen = new HashSet<int>();
            var alpha = _started ? _clock.InterpolationAlpha : 0;
            for (var i = 0; i < snapshot.Enemies.Count; i++)
            {
                var enemy = snapshot.Enemies[i];
                seen.Add(enemy.InstanceId);
                Transform marker;
                if (!_enemies.TryGetValue(enemy.InstanceId, out marker))
                {
                    marker = CreateSprite("Dangkang-" + enemy.InstanceId, Color.white, 3);
                    marker.localScale = new Vector3(0.34f, 0.34f, 1f);
                    _enemies.Add(enemy.InstanceId, marker);
                }

                var distance = enemy.Distance + (enemy.Speed * alpha);
                if (distance > _sim.Path.Length)
                {
                    distance = _sim.Path.Length;
                }

                var point = _sim.Path.Sample(distance);
                marker.position = ToWorld(point.X, point.Y);
                var hp = enemy.MaxHp <= 0 ? 0f : Mathf.Clamp01(enemy.Hp / (float)enemy.MaxHp);
                marker.GetComponent<SpriteRenderer>().color = Color.Lerp(new Color(0.75f, 0.2f, 0.16f, 1f), new Color(0.93f, 0.55f, 0.22f, 1f), hp);
            }

            var stale = new List<int>();
            foreach (var pair in _enemies)
            {
                if (!seen.Contains(pair.Key))
                {
                    stale.Add(pair.Key);
                }
            }

            for (var i = 0; i < stale.Count; i++)
            {
                Destroy(_enemies[stale[i]].gameObject);
                _enemies.Remove(stale[i]);
            }
        }

        private Transform CreateSprite(string name, Color color, int order)
        {
            var go = new GameObject(name);
            go.transform.SetParent(_viewRoot, false);
            var renderer = go.AddComponent<SpriteRenderer>();
            renderer.sprite = _pixel;
            renderer.color = color;
            renderer.sortingOrder = order;
            return go.transform;
        }

        private Sprite Pixel()
        {
            var texture = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            texture.SetPixel(0, 0, Color.white);
            texture.Apply();
            texture.filterMode = FilterMode.Point;
            return Sprite.Create(texture, new Rect(0f, 0f, 1f, 1f), new Vector2(0.5f, 0.5f), 1f);
        }

        private static Vector3 ToWorld(double x, double y)
        {
            return new Vector3((float)((x - 0.5) * PlayfieldSize), (float)((y - 0.5) * PlayfieldSize), 0f);
        }

        private static string PhaseLabel(BattlePhase phase)
        {
            switch (phase)
            {
                case BattlePhase.Ready:
                    return "准备";
                case BattlePhase.Running:
                    return "战斗中";
                case BattlePhase.Won:
                    return "胜利";
                case BattlePhase.Lost:
                    return "失败";
                default:
                    return phase.ToString();
            }
        }

        private static Rect StartRect()
        {
            return new Rect(24f, 24f, 200f, 46f);
        }

        private static Rect PlaceRect()
        {
            return new Rect(24f, 78f, 200f, 46f);
        }

        private static Rect SpeedRect()
        {
            return new Rect(24f, 132f, 200f, 46f);
        }

        private static Rect BackRect()
        {
            return new Rect(24f, 186f, 200f, 46f);
        }

        private static void DrawButton(Rect rect, string label)
        {
            GUI.Box(rect, GUIContent.none);
            GUI.Label(rect, label, Style(18, TextAnchor.MiddleCenter));
        }

        private static GUIStyle Style(int size, TextAnchor anchor)
        {
            var style = new GUIStyle(GUI.skin.label);
            style.fontSize = size;
            style.alignment = anchor;
            style.normal.textColor = Color.white;
            style.wordWrap = true;
            return style;
        }

        private static bool Pressed(Rect rect)
        {
            Vector2 gui;
            return TryPointerDown(out gui) && rect.Contains(gui);
        }

        private static bool TryPointerDown(out Vector2 gui)
        {
            gui = default;
            var mouse = Mouse.current;
            if (mouse != null && mouse.leftButton.wasPressedThisFrame)
            {
                var position = mouse.position.ReadValue();
                gui = new Vector2(position.x, Screen.height - position.y);
                return true;
            }

            var touch = Touchscreen.current;
            if (touch != null && touch.primaryTouch.press.wasPressedThisFrame)
            {
                var position = touch.primaryTouch.position.ReadValue();
                gui = new Vector2(position.x, Screen.height - position.y);
                return true;
            }

            return false;
        }

        private static bool PressedKey(Key key)
        {
            var keyboard = Keyboard.current;
            return keyboard != null && keyboard[key].wasPressedThisFrame;
        }
    }
}
