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
    /// 冀州 01 战斗桩：开战、放置剑阵、胜、负、1x/2x。表现只读快照，不改生命。
    /// 倍速交给 SimClock，不乘进伤害。
    /// 建造格按表顺序对应数字键 1/2/3（以及小键盘），也可直接点格子。
    /// T 或「放置剑阵」放到下一个空闲格。余额不足时模拟拒绝，这里只显示快照里的短提示。
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

        private const float WorldUnitsPerHeight = 9f;
        private const float PlayfieldWorldWidth = 16f;
        private const float PlayfieldWorldHeight = 9f;
        private const float BattleCameraSize = 4.5f;
        private const float RefWidth = 1920f;
        private const float RefHeight = 1080f;

        private readonly SimClock _clock = new SimClock();
        private readonly Dictionary<int, Transform> _enemies = new Dictionary<int, Transform>();
        private SliceBattleContent _content;
        private CombatSimulation _sim;
        private string _error = "读取切片表…";
        private bool _started;
        private bool _reported;
        private Transform _viewRoot;
        private readonly Dictionary<string, Transform> _towerMarks = new Dictionary<string, Transform>();
        private int _cellCursor;
        private Sprite _pixel;

        public event Action<BattleFinished> Finished;

        private void Awake()
        {
            FitBattleCamera();
        }

        private async void Start()
        {
            FitBattleCamera();
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

            if (PressedKey(Key.Digit1) || PressedKey(Key.Numpad1))
            {
                PlaceCell(0);
            }
            else if (PressedKey(Key.Digit2) || PressedKey(Key.Numpad2))
            {
                PlaceCell(1);
            }
            else if (PressedKey(Key.Digit3) || PressedKey(Key.Numpad3))
            {
                PlaceCell(2);
            }
            else if (Pressed(PlaceRect()) || PressedKey(Key.T))
            {
                PlaceNextFree();
            }
            else
            {
                int clicked;
                if (ClickedCell(out clicked))
                {
                    PlaceCell(clicked);
                }
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
            DrawButton(PlaceRect(), PlaceLabel());
            DrawButton(SpeedRect(), "倍速 " + _clock.Speed + "x");
            DrawButton(BackRect(), "回枢纽");

            var style = Style(18, TextAnchor.UpperLeft);
            var status = _error;
            string note = null;
            if (_sim != null && _content != null)
            {
                var snapshot = _sim.Snapshot;
                note = snapshot.Note;
                status = _content.Level.DisplayName
                    + "\n"
                    + PhaseLabel(snapshot.Phase)
                    + "  tick "
                    + snapshot.Tick
                    + "  波次 "
                    + snapshot.WaveNumber
                    + "/"
                    + snapshot.WaveCount
                    + "  场上 "
                    + snapshot.Enemies.Count
                    + "\n灵石 "
                    + snapshot.Balance
                    + "\n"
                    + DingHearts(snapshot.LeakCount, snapshot.LoseLeakCount)
                    + "  漏怪 "
                    + snapshot.LeakCount
                    + "/"
                    + snapshot.LoseLeakCount;
            }

            GUI.Label(StatusRect(), status ?? string.Empty, style);
            if (!string.IsNullOrEmpty(note))
            {
                var hint = Style(16, TextAnchor.MiddleLeft);
                hint.normal.textColor = new Color(1f, 0.86f, 0.45f, 1f);
                GUI.Label(NoteRect(), note, hint);
            }

            DrawCellLabels();
            GUI.Label(
                HelpRect(),
                "数字键 1/2/3 或点击建造格放置剑阵，T 放到下一个空格。开战前放 1 座可清完 8 波。不放塔则第 3 只漏出即失败。灵石不足会拒绝放置且不扣费。X 倍速，Enter 开战，Esc 回枢纽。",
                Style(16, TextAnchor.UpperLeft));

            if (_sim != null && (_sim.Phase == BattlePhase.Won || _sim.Phase == BattlePhase.Lost))
            {
                var banner = _sim.Phase == BattlePhase.Won ? "胜利" : "失败";
                var rect = BannerRect();
                GUI.Box(rect, GUIContent.none);
                GUI.Label(rect, banner, Style(40, TextAnchor.MiddleCenter));
            }
        }

        private string PlaceLabel()
        {
            if (_sim == null || _content == null || _sim.Snapshot == null)
            {
                return "放置剑阵";
            }

            var used = 0;
            var cells = _sim.Snapshot.Cells;
            for (var i = 0; i < cells.Count; i++)
            {
                if (cells[i].Occupied || cells[i].Queued)
                {
                    used++;
                }
            }

            return "放置剑阵 " + used + "/" + _content.Level.BuildCells.Count;
        }

        private void PlaceNextFree()
        {
            if (_sim == null || _content == null)
            {
                return;
            }

            var count = _content.Level.BuildCells.Count;
            if (count == 0)
            {
                return;
            }

            for (var n = 0; n < count; n++)
            {
                var index = (_cellCursor + n) % count;
                if (CellFree(index))
                {
                    _cellCursor = (index + 1) % count;
                    PlaceCell(index);
                    return;
                }
            }

            PlaceCell(_cellCursor % count);
        }

        private void PlaceCell(int index)
        {
            if (_sim == null || _content == null)
            {
                return;
            }

            var cells = _content.Level.BuildCells;
            if (index < 0 || index >= cells.Count)
            {
                return;
            }

            _sim.EnqueuePlace(_content.Tower.Id, cells[index].Id);
        }

        private bool CellFree(int index)
        {
            if (_sim == null || _sim.Snapshot == null || _content == null)
            {
                return false;
            }

            var id = _content.Level.BuildCells[index].Id;
            var cells = _sim.Snapshot.Cells;
            for (var i = 0; i < cells.Count; i++)
            {
                if (cells[i].Id == id)
                {
                    return !cells[i].Occupied && !cells[i].Queued;
                }
            }

            return true;
        }

        private bool ClickedCell(out int index)
        {
            index = -1;
            Vector2 gui;
            if (!TryPointerDown(out gui) || _content == null)
            {
                return false;
            }

            if (StartRect().Contains(gui) || PlaceRect().Contains(gui) || SpeedRect().Contains(gui) || BackRect().Contains(gui))
            {
                return false;
            }

            var camera = Camera.main;
            if (camera == null)
            {
                return false;
            }

            var best = 36f * 36f;
            var cells = _content.Level.BuildCells;
            for (var i = 0; i < cells.Count; i++)
            {
                var screen = camera.WorldToScreenPoint(ToWorld(cells[i].X, cells[i].Y));
                var dx = screen.x - gui.x;
                var dy = (Screen.height - screen.y) - gui.y;
                var distance = (dx * dx) + (dy * dy);
                if (distance <= best)
                {
                    best = distance;
                    index = i;
                }
            }

            return index >= 0;
        }

        private void DrawCellLabels()
        {
            if (_content == null)
            {
                return;
            }

            var camera = Camera.main;
            if (camera == null)
            {
                return;
            }

            var style = Style(16, TextAnchor.MiddleCenter);
            var cells = _content.Level.BuildCells;
            for (var i = 0; i < cells.Count; i++)
            {
                var screen = camera.WorldToScreenPoint(ToWorld(cells[i].X, cells[i].Y));
                GUI.Label(new Rect(screen.x - 18f, (Screen.height - screen.y) - 36f, 36f, 22f), (i + 1).ToString(), style);
            }
        }

        private static string DingHearts(int leaks, int max)
        {
            var left = max - leaks;
            if (left < 0)
            {
                left = 0;
            }

            if (left > max)
            {
                left = max;
            }

            return "铜鼎 " + new string('♥', left) + new string('♡', max - left) + " " + left + "/" + max;
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
            FitBattleCamera();
            _pixel = Pixel();
            _viewRoot = new GameObject("SliceView").transform;
            var board = CreateSprite("Playfield", new Color(0.1f, 0.12f, 0.14f, 1f), 0);
            var legacySquare = _content.Level.Space == SliceRules.SpaceNormalizedPlayfield;
            board.localScale = legacySquare
                ? new Vector3(PlayfieldWorldHeight, PlayfieldWorldHeight, 1f)
                : new Vector3(PlayfieldWorldWidth, PlayfieldWorldHeight, 1f);

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

            var cells = _content.Level.BuildCells;
            for (var i = 0; i < cells.Count; i++)
            {
                var cell = cells[i];
                var cellMark = CreateSprite("BuildCell-" + cell.Id, new Color(0.95f, 0.78f, 0.28f, 0.35f), 2);
                cellMark.position = ToWorld(cell.X, cell.Y);
                cellMark.localScale = new Vector3(0.55f, 0.55f, 1f);

                var tower = CreateSprite("TowerJin-" + cell.Id, new Color(0.96f, 0.82f, 0.28f, 1f), 4);
                tower.gameObject.SetActive(false);
                tower.localScale = new Vector3(0.42f, 0.42f, 1f);
                _towerMarks.Add(cell.Id, tower);
            }
        }

        private void SyncView()
        {
            if (_sim == null || _viewRoot == null)
            {
                return;
            }

            var snapshot = _sim.Snapshot;
            var shown = new HashSet<string>();
            for (var i = 0; i < snapshot.Towers.Count; i++)
            {
                var tower = snapshot.Towers[i];
                Transform marker;
                if (!_towerMarks.TryGetValue(tower.CellId, out marker))
                {
                    continue;
                }

                marker.gameObject.SetActive(true);
                marker.position = ToWorld(tower.X, tower.Y);
                marker.GetComponent<SpriteRenderer>().color = new Color(0.96f, 0.82f, 0.28f, 1f);
                shown.Add(tower.CellId);
            }

            for (var i = 0; i < snapshot.Cells.Count; i++)
            {
                var cell = snapshot.Cells[i];
                if (!cell.Queued || shown.Contains(cell.Id))
                {
                    continue;
                }

                Transform marker;
                if (!_towerMarks.TryGetValue(cell.Id, out marker))
                {
                    continue;
                }

                marker.gameObject.SetActive(true);
                marker.position = ToWorld(cell.X, cell.Y);
                marker.GetComponent<SpriteRenderer>().color = new Color(0.96f, 0.82f, 0.28f, 0.55f);
                shown.Add(cell.Id);
            }

            foreach (var pair in _towerMarks)
            {
                if (!shown.Contains(pair.Key))
                {
                    pair.Value.gameObject.SetActive(false);
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

        /// <summary>
        /// height_units_16x9：ToWorld(x,y) = ((x − 0.889) * 9, (y − 0.5) * 9)，战场 16×9，正交相机 size 4.5。
        /// 旧 normalized_playfield 仍映射成 9×9 方场，方便对照迁移前的表。
        /// </summary>
        private Vector3 ToWorld(double x, double y)
        {
            if (_content != null && _content.Level.Space == SliceRules.SpaceNormalizedPlayfield)
            {
                return new Vector3((float)((x - 0.5) * WorldUnitsPerHeight), (float)((y - 0.5) * WorldUnitsPerHeight), 0f);
            }

            return new Vector3((float)((x - 0.889) * WorldUnitsPerHeight), (float)((y - 0.5) * WorldUnitsPerHeight), 0f);
        }

        private static void FitBattleCamera()
        {
            var camera = Camera.main;
            if (camera == null)
            {
                return;
            }

            camera.orthographic = true;
            camera.orthographicSize = BattleCameraSize;
            camera.transform.position = new Vector3(0f, 0f, -10f);
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

        /// <summary>
        /// 按钮和说明落在 1920×1080 参考下的 HUD 安全区：顶 120px、底 100px、左右各 120px。
        /// 路径和建造格在这块之外。非 16:9 时按宽高分别缩放，左右裁切不在这里补黑边。
        /// </summary>
        private static Rect StartRect()
        {
            return new Rect(Sx(24f), Sy(28f), Sx(200f), Sy(64f));
        }

        private static Rect PlaceRect()
        {
            return new Rect(Sx(240f), Sy(28f), Sx(250f), Sy(64f));
        }

        private static Rect SpeedRect()
        {
            return new Rect(Sx(506f), Sy(28f), Sx(170f), Sy(64f));
        }

        private static Rect BackRect()
        {
            return new Rect(Sx(692f), Sy(28f), Sx(170f), Sy(64f));
        }

        private static Rect StatusRect()
        {
            return new Rect(Sx(880f), Sy(12f), Mathf.Max(120f, Screen.width - Sx(904f)), Sy(100f));
        }

        private static Rect NoteRect()
        {
            return new Rect(Sx(24f), Screen.height - Sy(100f), Mathf.Max(120f, Screen.width - Sx(48f)), Sy(30f));
        }

        private static Rect HelpRect()
        {
            return new Rect(Sx(24f), Screen.height - Sy(68f), Mathf.Max(120f, Screen.width - Sx(48f)), Sy(60f));
        }

        private static Rect BannerRect()
        {
            var width = Sx(320f);
            var height = Sy(80f);
            return new Rect((Screen.width - width) * 0.5f, (Screen.height - height) * 0.5f, width, height);
        }

        private static float Sx(float referenceX)
        {
            return referenceX * Screen.width / RefWidth;
        }

        private static float Sy(float referenceY)
        {
            return referenceY * Screen.height / RefHeight;
        }

        private static float UiScale()
        {
            var scale = Mathf.Min(Screen.width / RefWidth, Screen.height / RefHeight);
            if (scale < 0.65f)
            {
                return 0.65f;
            }

            return scale;
        }

        private static void DrawButton(Rect rect, string label)
        {
            GUI.Box(rect, GUIContent.none);
            GUI.Label(rect, label, Style(18, TextAnchor.MiddleCenter));
        }

        private static GUIStyle Style(int size, TextAnchor anchor)
        {
            var style = new GUIStyle(GUI.skin.label);
            style.fontSize = Mathf.Max(10, Mathf.RoundToInt(size * UiScale()));
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
