/*
 * Copyright (C) 2026 Kamil Lulko <kamil.lulko@gmail.com>
 *
 * This file is part of DoubleTracker.
 *
 * DoubleTracker is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * DoubleTracker is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with DoubleTracker. If not, see <https://www.gnu.org/licenses/>.
 */

declare name "DoubleTracker";
declare author "varcain";
declare version "1.0";

import("stdfaust.lib");

// === Control parameters ===
timing      = hslider("Timing", 0.5, 0.0, 1.0, 0.001);
push        = hslider("Push", 0.5, 0.0, 1.0, 0.001);
sensitivity = hslider("Sensitivity", 0.5, 0.0, 1.0, 0.001);
outGain     = hslider("Output", 0.0, -12.0, 6.0, 0.1) : ba.db2linear;

// === Constants ===
MAX_SR = 192000;  // assumed ceiling sample rate for buffer allocation
maxDelaySamples = int(0.060 * MAX_SR) + 1;
threshold = 0.005 + (1.0 - sensitivity) * 0.895;

// === Schmitt trigger with hysteresis ===
// Must drop below lo to re-arm, must exceed hi to fire
schmitt(lo, hi, sig) = loop ~ _
with {
    loop(prev) = (sig > hi) | ((sig >= lo) & prev);
};

// === Holdoff gate ===
// After trigger passes through, suppress for n samples
// Uses arithmetic instead of select2 to avoid routing issues
holdoffGate(n, trig) = (inner ~ _) : !,_
with {
    inner(prev) = newTimer, fired
    with {
        fired    = trig * (prev <= 0);
        newTimer = fired * n + (1.0 - fired) * max(0, prev - 1);
    };
};

// === Allpass phase shifting ===
// 8 cascaded first-order allpasses (H(z) = (a + z^-1) / (1 + a*z^-1))
// using fi.tf1(b0, b1, a1): y[n] = b0*x[n] + b1*x[n-1] - a1*y[n-1]
// Coefficients modulated by slow non-harmonically-related LFOs
depth = push * 0.95;
lfoScale = 1.0 + push * 5.0;  // LFO speed 1x–6x: faster modulation → audible pitch artifacts
c1 = os.osc(0.13 * lfoScale) * depth;
c2 = os.osc(0.21 * lfoScale) * depth;
c3 = os.osc(0.34 * lfoScale) * depth;
c4 = os.osc(0.55 * lfoScale) * depth;
c5 = os.osc(0.17 * lfoScale) * depth;
c6 = os.osc(0.29 * lfoScale) * depth;
c7 = os.osc(0.43 * lfoScale) * depth;
c8 = os.osc(0.67 * lfoScale) * depth;
allpassChain = fi.tf1(c1, 1, c1) : fi.tf1(c2, 1, c2)
             : fi.tf1(c3, 1, c3) : fi.tf1(c4, 1, c4)
             : fi.tf1(c5, 1, c5) : fi.tf1(c6, 1, c6)
             : fi.tf1(c7, 1, c7) : fi.tf1(c8, 1, c8);

// === Subtle pitch modulation ===
// Modulated delay line with filtered-noise LFO for stochastic intonation drift
pitchCenterMs = 5.0;
pitchDepthMs  = 10.0;
pitchMaxDelay = int((pitchCenterMs + pitchDepthMs * 2.0) * 0.001 * MAX_SR) + 1;
pitchLfo = no.noise : fi.lowpass(2, 0.7);

// === Subtle nonlinear coloring ===
// Asymmetric soft saturation for timbral variation between takes
// x^2 term → 2nd harmonic (asymmetry), x^3 term → 3rd harmonic (compression)
// Moderate effect at normal signal levels
subtleSat(x) = x - 0.15 * x * x - 0.20 * x * x * x;

// === Transient softener ===
// Slight attack reduction simulating pick angle/pressure variation
transientSoft(x) = x * gain
with {
    fast = abs(x) : si.smooth(ba.tau2pole(0.001));
    slow = abs(x) : si.smooth(ba.tau2pole(0.020));
    transRatio = max(0.0, fast - slow) / max(slow, ma.EPSILON);
    gain = 1.0 - 0.25 * min(1.0, transRatio);
};

// === Process: mono in → stereo out ===
process(x) = x * outGain, wet * outGain
with {
    // Onset detection: Schmitt trigger with 40% hysteresis + 50ms holdoff
    env      = x : an.amp_follower_ar(0.001, 0.050);
    above    = schmitt(threshold * 0.4, threshold, env);
    onsetRaw = above * (1 - (above @ 1));
    onset    = holdoffGate(int(0.050 * ma.SR), onsetRaw);

    // Dynamic pitch drift: increases during sustained notes
    timeSinceOnset = (+(1) ~ *(1 - onset));
    sustainFactor = 1.0 + min(1.0, timeSinceOnset / (0.5 * ma.SR));
    dynPitchDepth = pitchDepthMs * sustainFactor;
    pitchDelaySamp = (pitchCenterMs + pitchLfo * dynPitchDepth) * 0.001 * ma.SR;

    // Quasi-random slow wander for delay and drift
    wander1 = os.osc(0.037) * 0.5 + os.osc(0.051) * 0.3 + os.osc(0.079) * 0.2;
    wander2 = os.osc(0.029) * 0.5 + os.osc(0.043) * 0.3 + os.osc(0.071) * 0.2;
    wander3 = os.osc(0.031) * 0.5 + os.osc(0.047) * 0.3 + os.osc(0.073) * 0.2;

    // Random micro-delay position + slow drift
    rv = wander1 * 0.4 + 0.5;
    minMs = 5.0 + timing * 15.0;
    maxMs = 15.0 + timing * 45.0;
    drift = wander2 * 2.0;
    delayMs   = minMs + rv * (maxMs - minMs) + drift;
    delaySamp = delayMs * 0.001 * ma.SR : si.smooth(ba.tau2pole(0.015));

    // Fixed +1.5dB gain bias on wet channel
    onsetGain = ba.db2linear(1.5);

    ampDrift = 1.0;

    // Random spectral tilt: ±1.1dB
    tiltDb = wander3 * 1.1;

    // Wet path: micro-delay → allpass → pitch mod → spectral tilt → saturation → transient soft → gain
    wet = x : de.fdelay(maxDelaySamples, delaySamp) : allpassChain
        : de.fdelay(pitchMaxDelay, pitchDelaySamp)
        : fi.highshelf(1, tiltDb, 1000) : subtleSat : transientSoft
        : *(onsetGain * ampDrift);
};
