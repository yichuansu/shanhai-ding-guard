using System;
using System.Collections.Generic;
using ShanhaiDingGuard.Content;
using ShanhaiDingGuard.Gameplay.CombatSimulation;
using ShanhaiDingGuard.Gameplay.Path;
using UnityEngine;

namespace ShanhaiDingGuard.Presentation
{
    /// <summary>
    /// 把快照画成冀州 01 的塔、当康、铜鼎和建造格。
    /// 换帧只用模拟 tick 和帧间插值，不改 CombatSimulation 的结果。
    /// </summary>
    public sealed class BattleSpriteView
    {
        public const int SortPath = 10;
        public const int SortExit = 12;
        public const int SortSlot = 30;
        public const int SortUnit = 1000;
        public const int SortFx = 3000;

        private const float ShadowWorldWidth = 0.92f;
        private const float ShadowWorldHeight = 0.62f;
        private const float WalkFps = 10f;
        private const float FxFps = 12f;
        private const float HitFlashSeconds = 0.1f;
        private const float DeathHoldSeconds = 0.4f;
        private const float DeathFadeSeconds = 0.4f;

        private sealed class SlotVisual
        {
            public string Id;
            public SpriteRenderer Renderer;
        }

        private sealed class TowerVisual
        {
            public string CellId;
            public Transform Transform;
            public SpriteRenderer Renderer;
            public SpriteRenderer Shadow;
            public int Cooldown;
        }

        private sealed class EnemyVisual
        {
            public int InstanceId;
            public Transform Transform;
            public SpriteRenderer Renderer;
            public int LastHp;
            public float HitStart = -1f;
            public bool FacingLeft;
            public bool FacingKnown;
            public double LastX;
            public double LastY;
            public double LastDistance;
            public double LastSpeed;
        }

        private sealed class DeathVisual
        {
            public Transform Transform;
            public SpriteRenderer Renderer;
            public float Start;
        }

        private sealed class FxVisual
        {
            public SpriteRenderer Renderer;
            public float Start;
            public bool Active;
        }

        private readonly List<SlotVisual> _slots = new List<SlotVisual>();
        private readonly List<TowerVisual> _towers = new List<TowerVisual>();
        private readonly Dictionary<int, EnemyVisual> _enemies = new Dictionary<int, EnemyVisual>();
        private readonly List<DeathVisual> _deaths = new List<DeathVisual>();
        private readonly List<FxVisual> _fx = new List<FxVisual>();
        private BattleArt _art = new BattleArt();
        private Sprite _shadowSprite;
        private SliceBattleContent _content;
        private Transform _root;
        private Sprite _pixel;
        private Func<double, double, Vector3> _toWorld;
        private int _syncedTick = -1;
        private int _lastLeak;
        private float _afterBattle;

        public BattleArt Art
        {
            get { return _art; }
        }

        public void Build(Transform root, SliceBattleContent content, Func<double, double, Vector3> toWorld, Sprite pixel)
        {
            _root = root;
            _content = content;
            _toWorld = toWorld;
            _pixel = pixel;
            _art = BattleArt.Load();
            var cells = content.Level.BuildCells;
            for (var i = 0; i < cells.Count; i++)
            {
                var cell = cells[i];
                var slotGo = Create("BuildCell-" + cell.Id, _art.Ready ? _art.SlotNormal : _pixel, SortSlot);
                slotGo.transform.position = _toWorld(cell.X, cell.Y);
                if (!_art.Ready)
                {
                    slotGo.transform.localScale = new Vector3(0.55f, 0.55f, 1f);
                    slotGo.GetComponent<SpriteRenderer>().color = new Color(0.95f, 0.78f, 0.28f, 0.16f);
                }

                _slots.Add(new SlotVisual
                {
                    Id = cell.Id,
                    Renderer = slotGo.GetComponent<SpriteRenderer>(),
                });

                var towerGo = Create("TowerJin-" + cell.Id, _art.Ready ? _art.TowerBody : _pixel, SortUnit);
                towerGo.SetActive(false);
                if (!_art.Ready)
                {
                    towerGo.transform.localScale = new Vector3(0.42f, 0.42f, 1f);
                }

                SpriteRenderer shadow = null;
                if (_art.Ready)
                {
                    var shadowSprite = ShadowSprite();
                    var shadowGo = Create("TowerShadow-" + cell.Id, shadowSprite, SortSlot + 1);
                    shadowGo.transform.SetParent(towerGo.transform, false);
                    shadowGo.transform.localPosition = Vector3.zero;
                    var fittedHeight = shadowSprite.rect.height / shadowSprite.pixelsPerUnit;
                    if (fittedHeight > 0f)
                    {
                        shadowGo.transform.localScale = new Vector3(1f, ShadowWorldHeight / fittedHeight, 1f);
                    }

                    shadow = shadowGo.GetComponent<SpriteRenderer>();
                }

                _towers.Add(new TowerVisual
                {
                    CellId = cell.Id,
                    Transform = towerGo.transform,
                    Renderer = towerGo.GetComponent<SpriteRenderer>(),
                    Shadow = shadow,
                });
            }

            if (_art.Ready && _art.Ding != null && content.Level.Waypoints.Count > 0)
            {
                var exit = content.Level.Waypoints[content.Level.Waypoints.Count - 1];
                var ding = Create("DingBronze", _art.Ding, SortUnit);
                var position = _toWorld(exit.X, exit.Y);
                ding.transform.position = position;
                ding.GetComponent<SpriteRenderer>().sortingOrder = UnitOrder(position.y);
            }
        }

        public void Sync(CombatSimulation sim, SimClock clock, bool started, int cursorCell)
        {
            if (sim == null || sim.Snapshot == null || _root == null)
            {
                return;
            }

            var snapshot = sim.Snapshot;
            var alpha = 0f;
            if (started && sim.Phase == BattlePhase.Running)
            {
                alpha = (float)clock.InterpolationAlpha;
                _afterBattle = 0f;
            }
            else if (started)
            {
                _afterBattle += Time.deltaTime;
            }

            var anim = (float)((snapshot.Tick + alpha) * SimClock.TickSeconds) + _afterBattle;
            var tickDelta = _syncedTick < 0 ? 0 : snapshot.Tick - _syncedTick;
            if (tickDelta < 0)
            {
                tickDelta = 0;
            }

            _syncedTick = snapshot.Tick;
            if (_art.Ready)
            {
                SyncArt(sim, snapshot, alpha, anim, tickDelta, cursorCell);
            }
            else
            {
                SyncFallback(sim, snapshot, alpha);
            }

            UpdateDeaths(anim);
            UpdateFxFrames(anim);
        }

        private void SyncArt(CombatSimulation sim, BattleSnapshot snapshot, float alpha, float anim, int tickDelta, int cursorCell)
        {
            var gone = CollectGone(snapshot);
            var deaths = new List<EnemyVisual>();
            var leaks = snapshot.LeakCount - _lastLeak;
            if (leaks < 0)
            {
                leaks = 0;
            }

            // 同一帧里漏掉的是走得最远的那几只。其余消失的是被击杀，播死亡。
            gone.Sort((a, b) => a.LastDistance.CompareTo(b.LastDistance));
            var leakFrom = gone.Count - leaks;
            if (leakFrom < 0)
            {
                leakFrom = 0;
            }

            for (var i = 0; i < gone.Count; i++)
            {
                if (i >= leakFrom)
                {
                    UnityEngine.Object.Destroy(gone[i].Transform.gameObject);
                    _enemies.Remove(gone[i].InstanceId);
                }
                else
                {
                    deaths.Add(gone[i]);
                    BeginDeath(gone[i], anim);
                }
            }

            _lastLeak = snapshot.LeakCount;
            var shownTowers = new HashSet<string>();
            for (var i = 0; i < snapshot.Towers.Count; i++)
            {
                var tower = snapshot.Towers[i];
                var marker = FindTower(tower.CellId);
                if (marker == null)
                {
                    continue;
                }

                var cell = _toWorld(tower.X, tower.Y);
                marker.Transform.gameObject.SetActive(true);
                marker.Transform.position = SeatPosition(cell);
                marker.Renderer.color = Color.white;
                marker.Renderer.sortingOrder = UnitOrder(marker.Transform.position.y);
                ApplyShadow(marker, 1f);
                shownTowers.Add(tower.CellId);
            }

            for (var i = 0; i < snapshot.Cells.Count; i++)
            {
                var cell = snapshot.Cells[i];
                var slot = FindSlot(cell.Id);
                var marker = FindTower(cell.Id);
                if (slot == null)
                {
                    continue;
                }

                if (cell.Occupied)
                {
                    // 建成后只藏建造格贴图，不改格子坐标或模拟占用。
                    slot.Renderer.enabled = false;
                    continue;
                }

                slot.Renderer.enabled = true;
                slot.Renderer.sprite = SlotSprite(cell, IndexOfCell(cell.Id), cursorCell, snapshot.Balance);
                if (cell.Queued && marker != null)
                {
                    var at = _toWorld(cell.X, cell.Y);
                    marker.Transform.gameObject.SetActive(true);
                    marker.Transform.position = SeatPosition(at);
                    marker.Renderer.color = new Color(1f, 1f, 1f, 0.55f);
                    marker.Renderer.sortingOrder = UnitOrder(marker.Transform.position.y);
                    ApplyShadow(marker, 0.55f);
                    shownTowers.Add(cell.Id);
                }
            }

            for (var i = 0; i < _towers.Count; i++)
            {
                if (!shownTowers.Contains(_towers[i].CellId))
                {
                    _towers[i].Transform.gameObject.SetActive(false);
                    _towers[i].Cooldown = 0;
                }
            }

            for (var i = 0; i < snapshot.Enemies.Count; i++)
            {
                var enemy = snapshot.Enemies[i];
                var distance = enemy.Distance + (enemy.Speed * alpha);
                if (distance > sim.Path.Length)
                {
                    distance = sim.Path.Length;
                }

                var point = sim.Path.Sample(distance);
                var world = _toWorld(point.X, point.Y);
                EnemyVisual visual;
                if (!_enemies.TryGetValue(enemy.InstanceId, out visual))
                {
                    var go = Create("Dangkang-" + enemy.InstanceId, _art.Walk[0], SortUnit);
                    visual = new EnemyVisual
                    {
                        InstanceId = enemy.InstanceId,
                        Transform = go.transform,
                        Renderer = go.GetComponent<SpriteRenderer>(),
                        LastHp = enemy.Hp,
                    };
                    _enemies.Add(enemy.InstanceId, visual);
                }

                if (enemy.Hp < visual.LastHp)
                {
                    visual.HitStart = anim;
                }

                visual.LastHp = enemy.Hp;
                visual.LastX = enemy.X;
                visual.LastY = enemy.Y;
                visual.LastDistance = enemy.Distance;
                visual.LastSpeed = enemy.Speed;
                visual.Transform.position = world;
                visual.Renderer.sortingOrder = UnitOrder(world.y);
                ApplyFacing(visual, sim.Path, distance);
                visual.Renderer.sprite = EnemySprite(visual, distance, enemy.Speed, anim);
                visual.Renderer.color = Color.white;
            }

            StepAttacks(snapshot, deaths, tickDelta, anim);
        }

        private void SyncFallback(CombatSimulation sim, BattleSnapshot snapshot, float alpha)
        {
            var shown = new HashSet<string>();
            for (var i = 0; i < snapshot.Towers.Count; i++)
            {
                var tower = snapshot.Towers[i];
                var marker = FindTower(tower.CellId);
                if (marker == null)
                {
                    continue;
                }

                marker.Transform.gameObject.SetActive(true);
                marker.Transform.position = _toWorld(tower.X, tower.Y);
                marker.Renderer.color = new Color(0.96f, 0.82f, 0.28f, 1f);
                marker.Renderer.sortingOrder = UnitOrder(marker.Transform.position.y);
                shown.Add(tower.CellId);
            }

            for (var i = 0; i < snapshot.Cells.Count; i++)
            {
                var cell = snapshot.Cells[i];
                if (!cell.Queued || shown.Contains(cell.Id))
                {
                    continue;
                }

                var marker = FindTower(cell.Id);
                if (marker == null)
                {
                    continue;
                }

                marker.Transform.gameObject.SetActive(true);
                marker.Transform.position = _toWorld(cell.X, cell.Y);
                marker.Renderer.color = new Color(0.96f, 0.82f, 0.28f, 0.55f);
                marker.Renderer.sortingOrder = UnitOrder(marker.Transform.position.y);
                shown.Add(cell.Id);
            }

            for (var i = 0; i < _towers.Count; i++)
            {
                if (!shown.Contains(_towers[i].CellId))
                {
                    _towers[i].Transform.gameObject.SetActive(false);
                }
            }

            var seen = new HashSet<int>();
            for (var i = 0; i < snapshot.Enemies.Count; i++)
            {
                var enemy = snapshot.Enemies[i];
                seen.Add(enemy.InstanceId);
                EnemyVisual visual;
                if (!_enemies.TryGetValue(enemy.InstanceId, out visual))
                {
                    var go = Create("Dangkang-" + enemy.InstanceId, _pixel, SortUnit);
                    go.transform.localScale = new Vector3(0.34f, 0.34f, 1f);
                    visual = new EnemyVisual
                    {
                        InstanceId = enemy.InstanceId,
                        Transform = go.transform,
                        Renderer = go.GetComponent<SpriteRenderer>(),
                    };
                    _enemies.Add(enemy.InstanceId, visual);
                }

                var distance = enemy.Distance + (enemy.Speed * alpha);
                if (distance > sim.Path.Length)
                {
                    distance = sim.Path.Length;
                }

                var point = sim.Path.Sample(distance);
                var world = _toWorld(point.X, point.Y);
                visual.Transform.position = world;
                visual.Renderer.sortingOrder = UnitOrder(world.y);
                var hp = enemy.MaxHp <= 0 ? 0f : Mathf.Clamp01(enemy.Hp / (float)enemy.MaxHp);
                visual.Renderer.color = Color.Lerp(new Color(0.75f, 0.2f, 0.16f, 1f), new Color(0.93f, 0.55f, 0.22f, 1f), hp);
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
                UnityEngine.Object.Destroy(_enemies[stale[i]].Transform.gameObject);
                _enemies.Remove(stale[i]);
            }
        }

        private List<EnemyVisual> CollectGone(BattleSnapshot snapshot)
        {
            var alive = new HashSet<int>();
            for (var i = 0; i < snapshot.Enemies.Count; i++)
            {
                alive.Add(snapshot.Enemies[i].InstanceId);
            }

            var gone = new List<EnemyVisual>();
            foreach (var pair in _enemies)
            {
                if (!alive.Contains(pair.Key))
                {
                    gone.Add(pair.Value);
                }
            }

            return gone;
        }

        private void BeginDeath(EnemyVisual visual, float anim)
        {
            _enemies.Remove(visual.InstanceId);
            if (_art.Death == null)
            {
                UnityEngine.Object.Destroy(visual.Transform.gameObject);
                return;
            }

            visual.Renderer.sprite = _art.Death;
            visual.Renderer.color = Color.white;
            visual.Renderer.flipX = visual.FacingLeft;
            _deaths.Add(new DeathVisual
            {
                Transform = visual.Transform,
                Renderer = visual.Renderer,
                Start = anim,
            });
        }

        private void UpdateDeaths(float anim)
        {
            for (var i = _deaths.Count - 1; i >= 0; i--)
            {
                var death = _deaths[i];
                var age = anim - death.Start;
                var alpha = 1f;
                if (age >= DeathHoldSeconds)
                {
                    alpha = 1f - ((age - DeathHoldSeconds) / DeathFadeSeconds);
                }

                if (age >= DeathHoldSeconds + DeathFadeSeconds || alpha <= 0f)
                {
                    UnityEngine.Object.Destroy(death.Transform.gameObject);
                    _deaths.RemoveAt(i);
                    continue;
                }

                death.Renderer.color = new Color(1f, 1f, 1f, alpha);
            }
        }

        private void StepAttacks(BattleSnapshot snapshot, List<EnemyVisual> deaths, int tickDelta, float anim)
        {
            var interval = _content.Tower.AttackIntervalTicks;
            if (interval < 1)
            {
                interval = 1;
            }

            for (var i = 0; i < snapshot.Towers.Count; i++)
            {
                var tower = snapshot.Towers[i];
                var marker = FindTower(tower.CellId);
                if (marker == null)
                {
                    continue;
                }

                for (var n = 0; n < tickDelta; n++)
                {
                    if (marker.Cooldown > 0)
                    {
                        marker.Cooldown--;
                    }

                    if (marker.Cooldown == 0 && WouldFire(tower, snapshot, deaths))
                    {
                        SpawnFx(marker, anim);
                        marker.Cooldown = interval;
                    }
                }
            }
        }

        private static bool WouldFire(TowerView tower, BattleSnapshot snapshot, List<EnemyVisual> deaths)
        {
            for (var i = 0; i < snapshot.Enemies.Count; i++)
            {
                var enemy = snapshot.Enemies[i];
                if (InRange(enemy.X, enemy.Y, tower))
                {
                    return true;
                }
            }

            for (var i = 0; i < deaths.Count; i++)
            {
                if (InRange(deaths[i].LastX, deaths[i].LastY, tower))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool InRange(double x, double y, TowerView tower)
        {
            var dx = x - tower.X;
            var dy = y - tower.Y;
            var range = tower.Range;
            return (dx * dx) + (dy * dy) <= (range * range) + 1e-9;
        }

        private void SpawnFx(TowerVisual tower, float anim)
        {
            if (_art.TowerFx == null || _art.TowerFx.Length == 0)
            {
                return;
            }

            FxVisual slot = null;
            for (var i = 0; i < _fx.Count; i++)
            {
                if (!_fx[i].Active)
                {
                    slot = _fx[i];
                    break;
                }
            }

            if (slot == null)
            {
                var go = Create("TowerJinFx", _art.TowerFx[0], SortFx);
                var renderer = go.GetComponent<SpriteRenderer>();
                if (_art.Additive != null)
                {
                    renderer.sharedMaterial = _art.Additive;
                }

                slot = new FxVisual { Renderer = renderer };
                _fx.Add(slot);
            }

            var body = _art.TowerBody;
            var lift = 0.55f;
            if (body != null && body.rect.height > 0f)
            {
                var height = body.rect.height / body.pixelsPerUnit;
                var pivot = body.pivot.y / body.rect.height;
                lift = (0.5f - pivot) * height;
            }

            slot.Active = true;
            slot.Start = anim;
            slot.Renderer.enabled = true;
            slot.Renderer.sprite = _art.TowerFx[0];
            slot.Renderer.color = Color.white;
            slot.Renderer.sortingOrder = SortFx;
            slot.Renderer.transform.position = tower.Transform.position + new Vector3(0f, lift, 0f);
        }

        private void UpdateFxFrames(float anim)
        {
            if (_art.TowerFx == null)
            {
                return;
            }

            for (var i = 0; i < _fx.Count; i++)
            {
                var fx = _fx[i];
                if (!fx.Active)
                {
                    continue;
                }

                var frame = Mathf.FloorToInt((anim - fx.Start) * FxFps);
                if (frame < 0 || frame >= _art.TowerFx.Length)
                {
                    fx.Active = false;
                    fx.Renderer.enabled = false;
                    continue;
                }

                fx.Renderer.sprite = _art.TowerFx[frame];
            }
        }

        private Sprite EnemySprite(EnemyVisual visual, double distance, double speed, float anim)
        {
            var frames = _art.Walk;
            var frame = 0;
            if (frames != null && frames.Length > 0 && speed > 1e-8)
            {
                var steps = (float)(distance / speed);
                frame = Mathf.FloorToInt(steps * (WalkFps * (float)SimClock.TickSeconds));
                frame %= frames.Length;
                if (frame < 0)
                {
                    frame += frames.Length;
                }
            }

            var sprite = frames != null && frames.Length > 0 ? frames[frame] : null;
            if (visual.HitStart >= 0f)
            {
                var age = anim - visual.HitStart;
                if (age >= 0f && age < HitFlashSeconds)
                {
                    sprite = age < HitFlashSeconds * 0.5f ? _art.HitWhite : _art.HitRed;
                }
            }

            return sprite;
        }

        private static void ApplyFacing(EnemyVisual visual, PathCurve path, double distance)
        {
            var aheadDistance = distance + 0.02;
            if (aheadDistance > path.Length)
            {
                aheadDistance = path.Length;
            }

            var here = path.Sample(distance);
            var ahead = path.Sample(aheadDistance);
            var dx = ahead.X - here.X;
            if (dx < -1e-5)
            {
                visual.FacingLeft = true;
                visual.FacingKnown = true;
            }
            else if (dx > 1e-5)
            {
                visual.FacingLeft = false;
                visual.FacingKnown = true;
            }

            visual.Renderer.flipX = visual.FacingLeft;
        }

        private Sprite SlotSprite(CellView cell, int index, int cursor, int balance)
        {
            if (cell.Queued)
            {
                return _art.SlotSelected;
            }

            var cost = _content.Tower.BuildCost;
            if (balance < cost)
            {
                return _art.SlotDisabled;
            }

            if (index == cursor)
            {
                return _art.SlotSelected;
            }

            return _art.SlotNormal;
        }

        private int IndexOfCell(string id)
        {
            var cells = _content.Level.BuildCells;
            for (var i = 0; i < cells.Count; i++)
            {
                if (cells[i].Id == id)
                {
                    return i;
                }
            }

            return -1;
        }

        /// <summary>
        /// 塔身 pivot 是底座椭圆中心，落在建造格上就和背景石台同心。
        /// 以前 pivot 在底边，再把画布底边下移 0.03，椭圆中心会浮在格心上方。
        /// </summary>
        private static Vector3 SeatPosition(Vector3 cell)
        {
            return cell;
        }

        private static void ApplyShadow(TowerVisual marker, float alpha)
        {
            if (marker.Shadow == null)
            {
                return;
            }

            marker.Shadow.color = new Color(1f, 1f, 1f, alpha);
            marker.Shadow.sortingOrder = marker.Renderer.sortingOrder - 1;
        }

        private Sprite ShadowSprite()
        {
            if (_shadowSprite != null)
            {
                return _shadowSprite;
            }

            const int width = 128;
            const int height = 86;
            var texture = new Texture2D(width, height, TextureFormat.RGBA32, false);
            texture.wrapMode = TextureWrapMode.Clamp;
            texture.filterMode = FilterMode.Bilinear;
            var pixels = new Color32[width * height];
            var cx = (width - 1) * 0.5f;
            var cy = (height - 1) * 0.5f;
            var rx = width * 0.5f;
            var ry = height * 0.5f;
            for (var y = 0; y < height; y++)
            {
                for (var x = 0; x < width; x++)
                {
                    var nx = (x - cx) / rx;
                    var ny = (y - cy) / ry;
                    var d = (nx * nx) + (ny * ny);
                    byte a = 0;
                    if (d < 1f)
                    {
                        var t = 1f - d;
                        a = (byte)Mathf.Clamp(Mathf.RoundToInt(t * t * 0.42f * 255f), 0, 255);
                    }

                    pixels[(y * width) + x] = new Color32(0, 0, 0, a);
                }
            }

            texture.SetPixels32(pixels);
            texture.Apply();
            var ppu = width / ShadowWorldWidth;
            _shadowSprite = Sprite.Create(texture, new Rect(0f, 0f, width, height), new Vector2(0.5f, 0.5f), ppu);
            return _shadowSprite;
        }

        private static int UnitOrder(float worldY)
        {
            return SortUnit - Mathf.RoundToInt(worldY * 100f);
        }

        private SlotVisual FindSlot(string id)
        {
            for (var i = 0; i < _slots.Count; i++)
            {
                if (_slots[i].Id == id)
                {
                    return _slots[i];
                }
            }

            return null;
        }

        private TowerVisual FindTower(string cellId)
        {
            for (var i = 0; i < _towers.Count; i++)
            {
                if (_towers[i].CellId == cellId)
                {
                    return _towers[i];
                }
            }

            return null;
        }

        private GameObject Create(string name, Sprite sprite, int order)
        {
            var go = new GameObject(name);
            go.transform.SetParent(_root, false);
            var renderer = go.AddComponent<SpriteRenderer>();
            renderer.sprite = sprite != null ? sprite : _pixel;
            renderer.sortingOrder = order;
            renderer.color = Color.white;
            return go;
        }
    }
}
