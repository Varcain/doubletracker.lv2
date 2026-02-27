# DoubleTracker

An LV2 guitar double-tracking plugin written in [Faust](https://faust.grame.fr/). Simulates the sound of two separate guitar takes panned hard left/right, without requiring the guitarist to actually play the part twice.

## How It Works

The plugin takes a mono guitar input and produces stereo output: the dry signal on the left channel and an algorithmically "doubled" copy on the right.

The wet path applies three layers of processing to differentiate it from the dry signal:

1. **Micro-delay** - On each detected pick onset, a new random delay (1-60 ms depending on Timing) is chosen and smoothly crossfaded. This simulates the natural timing variation between two separate performances.
2. **Allpass phase shifting** - 8 cascaded first-order allpass filters with slowly modulated coefficients create subtle timbral differences, similar to the comb-filtering that occurs when two mics capture the same source at slightly different positions.
3. **Pitch modulation** - A very slow (~0.07 Hz) modulated delay line adds ~0.15 ms of pitch drift, simulating the micro-intonation differences between two takes.

## Parameters

| Parameter | Range | Description |
|---|---|---|
| **Timing** | 0.0 - 1.0 | Controls the range of random micro-delays. Low values give tight, chorus-like doubling. High values give a looser, more human feel. |
| **Push** | 0.0 - 1.0 | Controls the depth of allpass phase shifting. At 0 the wet signal is timbrally identical to the dry. At 1.0 there is noticeable tonal movement. |
| **Sensitivity** | 0.0 - 1.0 | Controls onset detection threshold. Low sensitivity only triggers new delay values on hard picks. High sensitivity triggers on soft playing too. |

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
