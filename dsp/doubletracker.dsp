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

// === Constants ===
MAX_SR = 192000;  // assumed ceiling sample rate for buffer allocation
maxDelaySamples = int(0.060 * MAX_SR);
threshold = 0.02 + (1.0 - sensitivity) * 0.48;

// === Sample and hold ===
// When t transitions to 1, sample x; otherwise hold previous value
sah(t, x) = (*(1.0 - t) + x * t) ~ _;

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
depth = push * 0.98;
c1 = os.osc(0.13) * depth;
c2 = os.osc(0.21) * depth;
c3 = os.osc(0.34) * depth;
c4 = os.osc(0.55) * depth;
c5 = os.osc(0.17) * depth;
c6 = os.osc(0.29) * depth;
c7 = os.osc(0.43) * depth;
c8 = os.osc(0.67) * depth;
allpassChain = fi.tf1(c1, 1, c1) : fi.tf1(c2, 1, c2)
             : fi.tf1(c3, 1, c3) : fi.tf1(c4, 1, c4)
             : fi.tf1(c5, 1, c5) : fi.tf1(c6, 1, c6)
             : fi.tf1(c7, 1, c7) : fi.tf1(c8, 1, c8);

// === Subtle pitch modulation ===
// Modulated delay line: ~0.15ms depth at 0.07 Hz
// Simulates intonation differences between two guitar takes
pitchCenterMs = 0.5;
pitchDepthMs  = 0.15;
pitchMaxDelay = int((pitchCenterMs + pitchDepthMs) * 0.001 * MAX_SR) + 1;
pitchDelaySamp = (pitchCenterMs + os.osc(0.07) * pitchDepthMs) * 0.001 * ma.SR;
pitchMod = de.fdelay(pitchMaxDelay, pitchDelaySamp);

// === Process: mono in → stereo out ===
// Left = dry (original), Right = doubled copy
// Pan hard L/R for classic double-tracked stereo guitar
process(x) = x, wet
with {
    // Onset detection: Schmitt trigger with 40% hysteresis + 50ms holdoff
    env      = abs(x) : an.amp_follower_ar(0.001, 0.050);
    above    = schmitt(threshold * 0.4, threshold, env);
    onsetRaw = above * (1 - (above @ 1));
    onset    = holdoffGate(0.050 * ma.SR, onsetRaw);

    // Random micro-delay: S&H noise on each onset trigger
    rv = sah(onset | (1 - (1@1)), no.noise) * 0.5 + 0.5;  // map [-1,1] → [0,1]
    minMs = 1.0 + timing * 9.0;
    maxMs = 5.0 + timing * 55.0;
    delayMs   = minMs + rv * (maxMs - minMs);
    delaySamp = delayMs * 0.001 * ma.SR : si.smooth(ba.tau2pole(0.005));

    // Wet path: micro-delay → allpass phase shifting → pitch modulation
    wet = x : de.fdelay(maxDelaySamples, delaySamp) : allpassChain : pitchMod;
};
