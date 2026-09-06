"""
Generates retro 8-bit sound effects in WAV format for the Godot RPG.
Uses only standard Python libraries (wave, struct, math).
"""
import wave
import struct
import math
import os

os.makedirs("assets/sounds", exist_ok=True)
SAMPLE_RATE = 22050

def write_wav(filename, samples):
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1)  # Mono
        wav.setsampwidth(2)  # 16-bit
        wav.setframerate(SAMPLE_RATE)
        data = bytearray()
        for s in samples:
            val = max(-32767, min(32767, int(s * 32767)))
            data += struct.pack('<h', val)
        wav.writeframes(data)
    print(f"Generated {filename}")

def sfx_slash():
    # White noise sweep downwards
    samples = []
    duration = 0.15
    total_samples = int(duration * SAMPLE_RATE)
    import random
    random.seed(42)
    for i in range(total_samples):
        t = i / total_samples
        amp = (1.0 - t) * 0.7
        freq = 800 * (1.0 - t * 0.8)
        sine = math.sin(2 * math.pi * freq * (i / SAMPLE_RATE))
        noise = (random.random() * 2 - 1) * 0.5
        samples.append((sine * 0.5 + noise * 0.5) * amp)
    write_wav("assets/sounds/slash.wav", samples)

def sfx_hit():
    # Punchy square hit
    samples = []
    duration = 0.12
    total_samples = int(duration * SAMPLE_RATE)
    for i in range(total_samples):
        t = i / total_samples
        amp = (1.0 - t) * 0.8
        freq = 220 * (1.0 - t * 0.7)
        phase = (i * freq / SAMPLE_RATE) % 1.0
        square = 1.0 if phase < 0.5 else -1.0
        samples.append(square * amp)
    write_wav("assets/sounds/hit.wav", samples)

def sfx_pickup():
    # Arpeggio chime (XP / coin)
    samples = []
    notes = [523.25, 659.25, 783.99, 1046.50]  # C5, E5, G5, C6
    note_dur = 0.05
    for freq in notes:
        total_samples = int(note_dur * SAMPLE_RATE)
        for i in range(total_samples):
            t = i / total_samples
            amp = (1.0 - t * 0.5) * 0.6
            val = math.sin(2 * math.pi * freq * (i / SAMPLE_RATE))
            samples.append(val * amp)
    write_wav("assets/sounds/pickup.wav", samples)

def sfx_levelup():
    # Victory fanfare arpeggio
    samples = []
    notes = [440, 554.37, 659.25, 880, 1108.73]
    note_dur = 0.08
    for idx, freq in enumerate(notes):
        dur = 0.2 if idx == len(notes) - 1 else note_dur
        total_samples = int(dur * SAMPLE_RATE)
        for i in range(total_samples):
            t = i / total_samples
            amp = (1.0 - t) * 0.6
            val = math.sin(2 * math.pi * freq * (i / SAMPLE_RATE))
            samples.append(val * amp)
    write_wav("assets/sounds/levelup.wav", samples)

def sfx_chat():
    # Gentle notification blip
    samples = []
    duration = 0.08
    total_samples = int(duration * SAMPLE_RATE)
    for i in range(total_samples):
        t = i / total_samples
        amp = (1.0 - t) * 0.4
        freq = 880 + 440 * t
        val = math.sin(2 * math.pi * freq * (i / SAMPLE_RATE))
        samples.append(val * amp)
    write_wav("assets/sounds/chat.wav", samples)

if __name__ == "__main__":
    sfx_slash()
    sfx_hit()
    sfx_pickup()
    sfx_levelup()
    sfx_chat()
    print("All audio SFX generated successfully!")
