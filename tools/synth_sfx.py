#!/usr/bin/env python3
"""程序合成占位音效（古乐器音色），输出到 assets/sfx/*.wav。正式音效到位后直接替换同名文件。

    pip install numpy
    python3 tools/synth_sfx.py
"""
import pathlib
import wave

import numpy as np

RATE = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(x, attack=0.002, decay=0.1):
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-x / decay)


def lowpass(sig, alpha):
    out = np.empty_like(sig)
    acc = 0.0
    for i, v in enumerate(sig):
        acc += alpha * (v - acc)
        out[i] = acc
    return out


def bell(freq, seconds, partials, decay):
    """编钟、磬一类：非谐泛音叠加，各自衰减。"""
    x = t(seconds)
    sig = np.zeros_like(x)
    for ratio, amp, d in partials:
        sig += amp * np.sin(2 * np.pi * freq * ratio * x) * np.exp(-x / (decay * d))
    return sig * np.clip(x / 0.003, 0, 1)


def save(name, sig, gain=0.8):
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * gain
    data = (sig * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # 命中：短促木击
    x = t(0.06)
    save("hit", lowpass(rng.standard_normal(len(x)), 0.35) * env(x, 0.001, 0.012) + 0.5 * np.sin(2 * np.pi * 900 * x) * env(x, 0.001, 0.01), 0.5)
    # 暴击：金属脆响
    x = t(0.18)
    save("crit", bell(1800, 0.18, [(1, 1, 1), (2.7, 0.6, 0.6), (5.1, 0.3, 0.4)], 0.05) + 0.4 * rng.standard_normal(len(x)) * env(x, 0.001, 0.01), 0.7)
    # 击杀：下滑的"噗"
    x = t(0.16)
    f = 320 * np.exp(-x * 12)
    save("kill", np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(x, 0.002, 0.06) + 0.3 * lowpass(rng.standard_normal(len(x)), 0.2) * env(x, 0.001, 0.03), 0.6)
    # 部署：低沉的鼓击
    x = t(0.25)
    f = 150 * np.exp(-x * 8) + 50
    save("deploy", np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(x, 0.002, 0.09) + 0.2 * lowpass(rng.standard_normal(len(x)), 0.1) * env(x, 0.001, 0.02), 0.8)
    # 升级：宫商角上行三音（五声音阶）
    notes = [523.25, 587.33, 659.25]
    parts = [bell(n, 0.35, [(1, 1, 1), (2.0, 0.3, 0.5), (3.0, 0.15, 0.3)], 0.15) for n in notes]
    gap = int(RATE * 0.08)
    sig = np.zeros(gap * 2 + len(parts[0]))
    for i, p in enumerate(parts):
        sig[i * gap:i * gap + len(p)] += p
    save("upgrade", sig, 0.6)
    # 捕获：编钟（非谐泛音，长余韵）
    save("capture", bell(392, 1.8, [(1, 1, 1), (2.76, 0.5, 0.7), (5.4, 0.25, 0.4), (8.93, 0.12, 0.25)], 0.6), 0.85)
    # 漏怪：锣
    x = t(1.4)
    gong = bell(110, 1.4, [(1, 1, 1), (1.47, 0.6, 0.8), (2.09, 0.5, 0.6), (2.56, 0.3, 0.5), (3.2, 0.2, 0.4)], 0.5)
    save("leak", gong + 0.3 * lowpass(rng.standard_normal(len(x)), 0.05) * env(x, 0.005, 0.2), 0.9)
    # 波次开始：两声鼓
    one = t(0.3)
    f = 110 * np.exp(-one * 6) + 45
    drum = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(one, 0.002, 0.12)
    sig = np.zeros(int(RATE * 0.55))
    sig[:len(drum)] += drum
    sig[int(RATE * 0.22):int(RATE * 0.22) + len(drum)] += drum * 0.8
    save("wave", sig, 0.85)
    # 技能：磬
    save("skill", bell(784, 1.0, [(1, 1, 1), (2.32, 0.5, 0.6), (4.25, 0.3, 0.4)], 0.3), 0.8)
    # 胜利：上行五声
    notes = [392.0, 440.0, 523.25, 587.33, 783.99]
    parts = [bell(n, 0.6, [(1, 1, 1), (2.0, 0.3, 0.5)], 0.25) for n in notes]
    gap = int(RATE * 0.12)
    sig = np.zeros(gap * 4 + len(parts[0]))
    for i, p in enumerate(parts):
        sig[i * gap:i * gap + len(p)] += p
    save("victory", sig, 0.7)
    # 失败：低锣
    save("defeat", bell(73, 2.0, [(1, 1, 1), (1.5, 0.5, 0.7), (2.3, 0.3, 0.5)], 0.7), 0.85)
    print("音效已生成到", OUT)


if __name__ == "__main__":
    main()
