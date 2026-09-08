#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform vec4 uColorHighlight;
uniform vec4 uColorBody;
uniform vec4 uColorShadow;
uniform vec4 uColorShelf;
uniform vec4 uColorGlaze;
uniform float uQuality;
uniform float uSeed;
uniform vec3 uLightDir;
uniform float uSunAltitude;
uniform float uDaylightFactor;
uniform float uTime;
uniform float uTextureStyle; // 0.0 = Lazure, 1.0 = Granulating, 2.0 = Blooms, 3.0 = Rough Rag

out vec4 fragColor;

// Precision hash
float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// 2D Value Noise
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);

  float a = hash(i + vec2(0.0, 0.0));
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));

  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 4-Octave Fractal Brownian Motion
float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
  for (int i = 0; i < 4; ++i) {
    v += a * noise(p);
    p = rot * p * 2.04 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

// Continuous, mathematically smooth distance to the organic outer Goetheanum contour.
// Evaluated analytically: ZERO line segments, ZERO polygonal vertices, 100% C1 smooth.
float distToOuter(vec2 p) {
  vec2 c = p - vec2(0.500, 0.500);

  // Subtle organic respiration / metamorphosis of the outer Goetheanum silhouette
  float breathY = sin(uTime * 0.35) * 0.005 + sin(uTime * 0.22) * 0.002;
  float breathX = cos(uTime * 0.32) * 0.004 + cos(uTime * 0.50) * 0.002;
  float archMod = sin(uTime * 0.35) * 0.003;
  float bottomMod = sin(uTime * 0.30) * 0.0025;

  // Wonky Steiner outer silhouette:
  // Top rail: asymmetrical crown leaning right (apex around c.x = +0.18, y = 0.015)
  float topCrown = (0.040 + archMod) * (1.0 - pow(clamp((c.x - 0.18) / 0.48, -1.0, 1.0), 2.0));

  // Right flank: living S-curve swelling outward at the lower third (c.y ~ +0.24)
  float rightSwell = 0.024 * exp(-pow((c.y - 0.24) / 0.16, 2.0));

  // Bottom rail: undulating wave lifting center-right (c.x ~ +0.15) and dipping deep on the left (c.x ~ -0.40) into the architectural foot
  float bottomWave = -(0.030 + bottomMod) * (1.0 - pow(clamp((c.x - 0.15) / 0.50, -1.0, 1.0), 2.0))
                     + 0.048 * smoothstep(-0.15, -0.42, c.x) * smoothstep(-0.10, 0.40, c.y);

  // Left flank: organic curve sweeping inward at mid-height
  float leftBow = 0.012 * (1.0 - clamp(c.y / 0.48, -1.0, 1.0) * clamp(c.y / 0.48, -1.0, 1.0)) * smoothstep(0.0, 0.25, -c.x);

  vec2 q = c;
  q.x -= rightSwell;
  q.x += leftBow;

  if (q.y < 0.0) {
    q.y += topCrown;
  } else {
    q.y -= bottomWave;
  }

  // Generous half-size encompassing the entire wonky frame (up to bounds ~ 0.01..0.99)
  vec2 halfSize = vec2(0.490 + breathX, 0.490 + breathY);
  float radius = 0.045;
  vec2 d = abs(q) - halfSize + radius;
  float extDist = length(max(d, 0.0));
  float intDist = min(max(d.x, d.y), 0.0);
  // Inside the card contour, returns positive distance from the outer perimeter
  return -(extDist + intDist - radius);
}

// Continuous, mathematically smooth distance to the inner window opening.
// Evaluated analytically: ZERO line segments, ZERO polygonal vertices, 100% C1 smooth.
float distToInner(vec2 p) {
  vec2 c = p - vec2(0.500, 0.500);

  // Inner window cutout matching the wonky Steiner opening
  // Top lintel arch
  float archLift = 0.025 * (1.0 - pow(clamp((c.x - 0.10) / 0.40, -1.0, 1.0), 2.0));

  // Bottom cutout wave: dips toward bottom-left echoing the outer foot
  float bottomInnerWave = -0.025 * (1.0 - pow(clamp(c.x / 0.40, -1.0, 1.0), 2.0))
                          - 0.035 * smoothstep(0.10, -0.35, c.x);

  vec2 q = c;
  if (q.y < 0.0) {
    q.y += archLift;
  } else {
    q.y += bottomInnerWave;
  }

  // Smooth rounded rectangle with generous fillet curvature
  vec2 halfSize = vec2(0.380, 0.335);
  float radius = 0.055;
  vec2 d = abs(q) - halfSize + radius;
  float extDist = length(max(d, 0.0));
  float intDist = min(max(d.x, d.y), 0.0);
  // On the frame (outside the cutout), returns positive distance from the inner reveal
  return extDist + intDist - radius;
}

// Faceted Architectural Heightfield
// Models sculpted planar facets like Steiner's carved wood/plaster:
// 1. Outer chamfer facet
// 2. Broad front sculpted face plateau
// 3. Inner reveal facet sloping inward into the window
float getFacetedHeight(vec2 p) {
  float dOut = max(distToOuter(p), 0.0);
  float dIn = max(distToInner(p), 0.0);

  // Outer chamfer facet
  float outerBevel = smoothstep(0.000, 0.036, dOut);

  // Inner reveal facet
  float innerRevealWidth = 0.032 + 0.010 * smoothstep(0.35, 0.85, p.y);
  float innerBevel = smoothstep(0.000, innerRevealWidth, dIn);

  // Faceted stone profile: flat face plateau between bevel creases
  float base = min(outerBevel, innerBevel);

  // Gentle Steiner crowning along the center of the stone ring
  float cross = clamp(dIn / max(dIn + dOut, 0.001), 0.0, 1.0);
  float crown = 0.08 * sin(cross * 3.14159265);

  return base + crown;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;

  // Continuous boundary distances for 3D bevel and lighting
  float dOut = distToOuter(uv);
  float dIn = distToInner(uv);

  // 1. Faceted Surface Normals & Creases
  vec2 eps = vec2(0.003, 0.0);
  float hR = getFacetedHeight(uv + eps.xy);
  float hL = getFacetedHeight(uv - eps.xy);
  float hD = getFacetedHeight(uv + eps.yx);
  float hU = getFacetedHeight(uv - eps.yx);
  float crest = getFacetedHeight(uv);

  vec3 normal = normalize(vec3((hL - hR) * 14.0, (hU - hD) * 14.0, 1.0));

  // 2. Facet Creases & Capillary Pooling Lines
  float innerCreaseDist = abs(dIn - 0.034);
  float innerCrease = pow(clamp(1.0 - innerCreaseDist * 36.0, 0.0, 1.0), 3.0);

  float outerCreaseDist = abs(dOut - 0.036);
  float outerCrease = pow(clamp(1.0 - outerCreaseDist * 32.0, 0.0, 1.0), 3.0);

  // 3. Directional Solar Modeling (Luminous Watercolor Wash, No Plastic Specular)
  vec3 lightDir = normalize(uLightDir);
  float directLight = max(0.0, dot(normal, lightDir));
  float ambientBounce = max(0.0, -normal.x * 0.40 - normal.y * 0.20) * 0.30;
  float illumination = clamp(mix(0.62, 0.74, uDaylightFactor) + directLight * 0.32 + ambientBounce, 0.0, 1.0);

  // 4. Natural Fluid Watercolor Puddle Simulation (Wet-on-Wet Lazure)
  // Subtle organic fluid mottling vectors (incommensurate harmonic orbital shifts)
  // These generate undulating local liquid pigment currents without directional conveyor-belt drift.
  vec2 flow1 = vec2(cos(uTime * 0.18), sin(uTime * 0.14)) * 0.14;
  vec2 flow2 = vec2(sin(uTime * 0.13), cos(uTime * 0.17)) * 0.14;

  vec2 q = vec2(
    fbm(uv * 2.0 + vec2(uSeed * 0.08 + 1.1, 3.3) + flow1),
    fbm(uv * 2.0 + vec2(5.5, uSeed * 0.08 + 7.7) + flow2)
  );
  vec2 r = vec2(
    fbm(uv * 2.2 + 1.6 * q + vec2(4.2, 2.1) + flow2 * 0.75),
    fbm(uv * 2.2 + 1.6 * q.yx + vec2(7.3, 8.9) + flow1 * 0.75)
  );

  vec2 washDrift = vec2(cos(uTime * 0.09), sin(uTime * 0.11)) * 0.08;
  float washBase = fbm(uv * 2.2 + 2.0 * r + washDrift);

  // Characteristic Drying Watermark Edges and Style-Specific Textural Dynamics
  float washDensity;
  float stylePaperReserveMult;
  float styleToothDepth;
  float styleGrainMix;
  float styleCreasePool;

  if (uTextureStyle < 0.5) {
    // -------------------------------------------------------------------------
    // 0. STEINER LAZURE: Ethereal, feathered, translucent atmospheric veils
    // -------------------------------------------------------------------------
    float softTide = pow(clamp(1.0 - abs(washBase - 0.46) * 2.8, 0.0, 1.0), 2.5);
    washDensity = clamp(washBase + softTide * 0.10, 0.0, 1.0);
    stylePaperReserveMult = 0.35;
    styleToothDepth = 0.026;
    styleGrainMix = 0.22;
    styleCreasePool = 0.20;
  } else if (uTextureStyle < 1.5) {
    // -------------------------------------------------------------------------
    // 1. GRANULATING MINERAL: Genuine pigment sedimentation in cold-pressed tooth
    // -------------------------------------------------------------------------
    float granFibers = noise(fragCoord * 0.65) * 0.55 + hash(fragCoord * 1.4) * 0.45;
    // Granulation concentrates heavily in deeper wash pools and recesses
    float granulation = (granFibers - 0.46) * smoothstep(0.18, 0.75, washBase) * 0.32;
    washDensity = clamp(washBase + granulation, 0.0, 1.0);
    stylePaperReserveMult = 0.30;
    styleToothDepth = 0.082; // Distinct tactile granulation speckles
    styleGrainMix = 0.65;
    styleCreasePool = 0.24;
  } else if (uTextureStyle < 2.5) {
    // -------------------------------------------------------------------------
    // 2. WET-IN-WET BLOOMS: Cauliflowers, backruns & capillary tide rings
    // -------------------------------------------------------------------------
    float bloomEdge1 = pow(clamp(1.0 - abs(washBase - 0.34) * 5.2, 0.0, 1.0), 4.0);
    float bloomEdge2 = pow(clamp(1.0 - abs(washBase - 0.56) * 4.6, 0.0, 1.0), 3.5);
    float bloomEdge3 = pow(clamp(1.0 - abs(washBase - 0.74) * 5.4, 0.0, 1.0), 4.0);
    float bloomHollow = smoothstep(0.34, 0.42, washBase) * smoothstep(0.56, 0.48, washBase) * 0.16;
    float bloomRims = (bloomEdge1 * 0.28 + bloomEdge2 * 0.24 + bloomEdge3 * 0.20) - bloomHollow;
    washDensity = clamp(washBase + bloomRims, 0.0, 1.0);
    stylePaperReserveMult = 0.38;
    styleToothDepth = 0.045;
    styleGrainMix = 0.30;
    styleCreasePool = 0.26;
  } else {
    // -------------------------------------------------------------------------
    // 3. ROUGH RAG & DRY-BRUSH: Torchon mould-made paper & skipping ridge reserves
    // -------------------------------------------------------------------------
    float ragFibers = (sin(fragCoord.x * 0.40) + sin(fragCoord.y * 0.40)) * 0.06;
    float dryBrushSkip = smoothstep(0.40, 0.88, crest) * 0.18;
    washDensity = clamp(washBase + ragFibers - dryBrushSkip, 0.0, 1.0);
    stylePaperReserveMult = 0.55; // Strong dry-brush paper reserves on high ridges
    styleToothDepth = 0.088;
    styleGrainMix = 0.50;
    styleCreasePool = 0.38; // Deep shadow pooling in stone creases
  }

  // 5. Goethean Multi-Chromatic Glazes (Color Temperature Variation)
  vec2 glazeFlow = vec2(sin(uTime * 0.10), cos(uTime * 0.12)) * 0.09;
  float coolGlazeField = fbm(uv * 2.4 + q.yx * 1.4 + vec2(2.8, 6.1) + glazeFlow);
  float coolWeight = smoothstep(0.55, 0.10, uv.x) * smoothstep(0.28, 0.72, coolGlazeField);

  float warmGlazeField = fbm(uv * 2.4 + 8.4 + q * 1.4 + vec2(0.0, 1.9) - glazeFlow);
  float warmWeight = smoothstep(0.38, 0.88, uv.x) * smoothstep(0.28, 0.72, warmGlazeField);

  // 6. Luminous Watercolor Paper Reserve (Dry Brush on Light Crests)
  float paperReserve = smoothstep(0.65, 1.02, crest) *
      smoothstep(0.55, 1.0, illumination) *
      smoothstep(0.20, 0.70, 1.0 - washDensity) *
      stylePaperReserveMult;

  // 7. Cold-Pressed Watercolor Paper Tooth & Pigment Granulation
  float paperFibers = noise(fragCoord * 0.22) * 0.65 + noise(fragCoord * 0.45) * 0.35;
  float paperTooth = hash(fragCoord * 1.6) - 0.5;
  float paperGrain = mix(paperFibers, paperTooth, styleGrainMix);

  // 8. Effective Pigment Concentration across the Paper (Balanced watercolor lazure)
  float effectivePigment = clamp(
      0.06 +
      washDensity * 0.40 +
      (1.0 - illumination) * 0.24 +
      innerCrease * styleCreasePool +
      outerCrease * 0.14 -
      paperReserve +
      (paperGrain - 0.5) * 0.05,
      0.0, 1.0
  );

  // 9. Translucent Glaze Optical Mixing
  vec3 washLight = uColorHighlight.rgb;
  vec3 washBody = uColorBody.rgb;
  vec3 washDeep = uColorShadow.rgb;
  vec3 washCrease = mix(uColorShadow.rgb, vec3(0.0), 0.30);
  vec3 paperBase = mix(vec3(0.98, 0.975, 0.96), washLight, 0.18);

  vec3 washColor;
  if (effectivePigment < 0.28) {
    washColor = mix(paperBase, washLight, effectivePigment / 0.28);
  } else if (effectivePigment < 0.58) {
    washColor = mix(washLight, washBody, (effectivePigment - 0.28) / 0.30);
  } else if (effectivePigment < 0.82) {
    washColor = mix(washBody, washDeep, (effectivePigment - 0.58) / 0.24);
  } else {
    washColor = mix(washDeep, washCrease, (effectivePigment - 0.82) / 0.18);
  }

  // Apply Cool Glaze Bloom (Turquoise / Rose Madder on left flank)
  washColor = mix(washColor, uColorGlaze.rgb, coolWeight * 0.26);

  // Apply Warm Glaze Bloom (Chartreuse / Raw Sienna on right flank)
  washColor = mix(washColor, uColorShelf.rgb, warmWeight * 0.22);

  // Diurnal chromatic warmth
  vec3 diurnalTint = mix(
    vec3(0.90, 0.94, 1.04),
    mix(vec3(1.04, 0.97, 0.90), vec3(1.0), smoothstep(0.15, 0.60, max(0.0, uSunAltitude))),
    uDaylightFactor
  );
  washColor *= diurnalTint;

  // Tactile paper tooth modulation
  washColor += vec3((paperGrain - 0.5) * styleToothDepth);

  // Path geometry and anti-aliasing are cleanly handled by Skia's canvas.drawPath
  fragColor = vec4(clamp(washColor, 0.0, 1.0), 1.0);
}
