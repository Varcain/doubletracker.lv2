# DoubleTracker

An LV2 guitar double-tracking plugin written in [Faust](https://faust.grame.fr/). Simulates the sound of two separate guitar takes panned hard left/right, without requiring the guitarist to actually play the part twice.

## How It Works

The plugin takes a mono guitar input and produces stereo output: the dry signal on the left channel and an algorithmically "doubled" copy on the right.

The wet path applies several layers of processing to differentiate it from the dry signal:

1. **Micro-delay** - A slowly wandering delay (5-60 ms depending on Timing) built from quasi-random sinusoidal wander plus a slow drift component. Simulates natural timing variation between two performances.
2. **Allpass phase shifting** - 8 cascaded first-order allpass filters with LFO-modulated coefficients. The Push control scales both the modulation depth and speed, creating timbral/phase differences between the channels.
3. **Pitch modulation** - A filtered-noise modulated delay line (centered at 5 ms, up to ±10 ms depth) adds stochastic pitch drift. Drift depth increases during sustained notes via onset detection.
4. **Spectral tilt** - A slowly wandering high-shelf filter (±1.1 dB at 1 kHz) provides time-varying tonal variation.
5. **Asymmetric saturation** - Soft clipping with 2nd and 3rd harmonic generation adds timbral coloring that differs from the dry signal.
6. **Transient softener** - Reduces fast attack transients by up to 25%, simulating pick angle and pressure variation between takes.

The wet channel has a fixed +1.5 dB gain bias to keep it consistently present in the mix.

## Parameters

| Parameter | Range | Default | Description |
|---|---|---|---|
| **Timing** | 0.0 - 1.0 | 0.5 | Controls the range of micro-delays (5-60 ms). Low values give tight doubling, high values give a looser feel. |
| **Push** | 0.0 - 1.0 | 0.5 | Controls allpass phase-shifting depth and LFO speed (1×-6×). At 0 the wet signal has no phase modulation. At 1.0 there is noticeable tonal movement. |
| **Sensitivity** | 0.0 - 1.0 | 0.5 | Onset detection threshold. Covers the full dynamic range from quiet DI picking (high sensitivity) to heavy distortion (low sensitivity). Used to scale pitch drift depth on sustained notes. |
| **Output** | -12 - +6 dB | 0 dB | Output gain applied to both channels. |

## Building

### Dependencies

- [Faust](https://faust.grame.fr/) compiler with `faust2lv2`
- Standard C/C++ build tools

### Build and Install

```sh
make            # builds the LV2 bundle
make install    # installs to ~/.lv2/
```

To install to a custom LV2 path:

```sh
make install PREFIX=/usr/lib/lv2
```

### Uninstall

```sh
make uninstall
```

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
