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
float distToOuterWithBreath(vec2 p, vec2 breathXY, float archMod, float bottomMod) {
  vec2 c = p - vec2(0.500, 0.500);

  // Wonky Steiner outer silhouette:
  // Top rail: asymmetrical crown leaning right (apex around c.x = +0.18, y = 0.015)
  float topCrownNorm = clamp((c.x - 0.18) / 0.48, -1.0, 1.0);
  float topCrown = (0.040 + archMod) * (1.0 - topCrownNorm * topCrownNorm);

  // Right flank: living S-curve swelling outward at the lower third (c.y ~ +0.24)
  float rightSwellArg = (c.y - 0.24) / 0.16;
  float rightSwell = 0.024 * exp(-(rightSwellArg * rightSwellArg));

  // Bottom rail: undulating wave lifting center-right (c.x ~ +0.15) and dipping deep on the left (c.x ~ -0.40) into the architectural foot
  float bottomNorm = clamp((c.x - 0.15) / 0.50, -1.0, 1.0);
  float bottomWave = -(0.030 + bottomMod) * (1.0 - bottomNorm * bottomNorm)
                     + 0.048 * smoothstep(-0.15, -0.42, c.x) * smoothstep(-0.10, 0.40, c.y);

  // Left flank: organic curve sweeping inward at mid-height
  float leftNorm = clamp(c.y / 0.48, -1.0, 1.0);
  float leftBow = 0.012 * (1.0 - leftNorm * leftNorm) * smoothstep(0.0, 0.25, -c.x);

  vec2 q = c;
  q.x -= rightSwell;
  q.x += leftBow;

  if (q.y < 0.0) {
    q.y += topCrown;
  } else {
    q.y -= bottomWave;
  }

  // Generous half-size encompassing the entire wonky frame (up to bounds ~ 0.01..0.99)
  vec2 halfSize = vec2(0.490, 0.490) + breathXY;
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
  float archNorm = clamp((c.x - 0.10) / 0.40, -1.0, 1.0);
  float archLift = 0.025 * (1.0 - archNorm * archNorm);

  // Bottom cutout wave: dips toward bottom-left echoing the outer foot
  float bottomInnerNorm = clamp(c.x / 0.40, -1.0, 1.0);
  float bottomInnerWave = -0.025 * (1.0 - bottomInnerNorm * bottomInnerNorm)
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

float evalFacetedHeightFromDists(float rawDOut, float rawDIn) {
  float dOut = max(rawDOut, 0.0);
  float dIn = max(rawDIn, 0.0);
  float totalDist = dOut + dIn;
  if (totalDist < 0.001) return 0.0;

  // Normalized cross-coordinate: 0.0 at outer perimeter, 1.0 at inner window reveal
  float t = clamp(dOut / totalDist, 0.0, 1.0);

  // Sculptural crowned cross-section (ridge crest around t = 0.42)
  float tCrest = 0.42;
  float profile;
  if (t < tCrest) {
    // Outer slope: rises from outer edge to crest (tilting towards outside)
    float u = t / tCrest;
    profile = sin(u * 1.5707963);
  } else {
    // Inner slope: slopes downward into recessed window cavity (tilting towards inside)
    float u = (t - tCrest) / (1.0 - tCrest);
    profile = cos(u * 1.5707963);
  }

  // Chiseled planar facets (characteristic of Rudolf Steiner's hand wood carving)
  float outerBevel = smoothstep(0.000, 0.024, dOut);
  float innerBevel = smoothstep(0.000, 0.024, dIn);
  float facetShape = profile * min(outerBevel, innerBevel);

  // Subtle hand-carved tool gouge texture along the wood grain
  float gouge = 0.025 * sin(t * 9.42) * profile;

  return facetShape * 0.52 + gouge;
}

// Faceted Architectural Heightfield
// Models sculpted planar facets like Steiner's carved wood/plaster:
// The rails have a continuous 3D crowned cross-section with chiseled facets,
// sloping from the outer edge up to a ridge crest, then sloping down into the window cavity.
float getFacetedHeight(vec2 p, vec2 breathXY, float archMod, float bottomMod) {
  return evalFacetedHeightFromDists(
    distToOuterWithBreath(p, breathXY, archMod, bottomMod),
    distToInner(p)
  );
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;

  // Precompute breathing parameters once per fragment
  float sinT035 = sin(uTime * 0.35);
  vec2 breathXY = vec2(
    cos(uTime * 0.32) * 0.004 + cos(uTime * 0.50) * 0.002,
    sinT035 * 0.005 + sin(uTime * 0.22) * 0.002
  );
  float archMod = sinT035 * 0.003;
  float bottomMod = sin(uTime * 0.30) * 0.0025;

  // Continuous boundary distances for 3D bevel and lighting
  float dOut = distToOuterWithBreath(uv, breathXY, archMod, bottomMod);
  float dIn = distToInner(uv);

  // 1. Faceted Surface Normals & Creases
  float crest = evalFacetedHeightFromDists(dOut, dIn);
  vec3 normal;
  if (dIn < -0.005 || dOut < -0.005) {
    normal = vec3(0.0, 0.0, 1.0);
  } else {
    vec2 eps = vec2(0.004, 0.0);
    float hR = getFacetedHeight(uv + eps.xy, breathXY, archMod, bottomMod);
    float hL = getFacetedHeight(uv - eps.xy, breathXY, archMod, bottomMod);
    float hD = getFacetedHeight(uv + eps.yx, breathXY, archMod, bottomMod);
    float hU = getFacetedHeight(uv - eps.yx, breathXY, archMod, bottomMod);
    normal = normalize(vec3((hL - hR) * 12.0, (hU - hD) * 12.0, 0.46));
  }

  // 2. Facet Creases & Capillary Pooling Lines
  float innerCreaseDist = abs(dIn - 0.034);
  float innerCrease = pow(clamp(1.0 - innerCreaseDist * 36.0, 0.0, 1.0), 3.0);

  float outerCreaseDist = abs(dOut - 0.036);
  float outerCrease = pow(clamp(1.0 - outerCreaseDist * 32.0, 0.0, 1.0), 3.0);

  // 3. Directional Diurnal Solar Modeling
  // Morning: lightDir comes from the LEFT (lightDir.x < 0)
  // Noon: lightDir comes from the TOP (lightDir.y < -0.75, lightDir.x ~ 0)
  // Evening: lightDir comes from the RIGHT (lightDir.x > 0)
  vec3 lightDir = normalize(uLightDir);
  float NdotL = dot(normal, lightDir);
  float directLight = max(0.0, NdotL);

  // Macro-scale sunlight falloff across the overall card plane
  vec2 cardUV = uv - vec2(0.50, 0.50);
  float macroSunSide = dot(cardUV, lightDir.xy);

  // Specular sheen along carved ridges facing the sun
  vec3 viewDir = vec3(0.0, 0.0, 1.0);
  vec3 halfVec = normalize(lightDir + viewDir);
  float specGlint = pow(max(0.0, dot(normal, halfVec)), 18.0) * directLight * 0.28;

  // Ambient wrap-around skylight
  float skyBounce = max(0.0, dot(normal, vec3(0.0, -0.4, 0.85))) * 0.22;

  // Composite daylight illumination: wide dynamic contrast so time-of-day changes are unmistakable
  float illumination = clamp(
    0.26 * uDaylightFactor + // ambient daylight base
    directLight * (0.48 * uDaylightFactor + 0.12) + // direct sunbeam on facing facets
    macroSunSide * 0.24 * uDaylightFactor + // overall sunbeam gradient across the card
    skyBounce * uDaylightFactor + // ambient skylight
    specGlint * uDaylightFactor + // mineral stone specular glint
    (1.0 - uDaylightFactor) * 0.25, // nocturnal moonlight base
    0.06, 1.0
  );

  // 4. Natural Fluid Watercolor Puddle Simulation (Wet-on-Wet Lazure)
  // Subtle organic fluid mottling vectors (incommensurate harmonic orbital shifts)
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
    float granulation = (granFibers - 0.46) * smoothstep(0.18, 0.75, washBase) * 0.32;
    washDensity = clamp(washBase + granulation, 0.0, 1.0);
    stylePaperReserveMult = 0.30;
    styleToothDepth = 0.082;
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
    stylePaperReserveMult = 0.55;
    styleToothDepth = 0.088;
    styleGrainMix = 0.50;
    styleCreasePool = 0.38;
  }

  // 5. Dynamic Goethean Multi-Chromatic Glazes following the Sun Trajectory
  // Sunward side receives warm golden/amber shelf wash; shadow side receives cool translucent glaze
  vec2 glazeFlow = vec2(sin(uTime * 0.10), cos(uTime * 0.12)) * 0.09;
  float coolGlazeField = fbm(uv * 2.4 + q.yx * 1.4 + vec2(2.8, 6.1) + glazeFlow);
  float warmGlazeField = fbm(uv * 2.4 + 8.4 + q * 1.4 + vec2(0.0, 1.9) - glazeFlow);

  float sunExposure = clamp(macroSunSide * 2.5 + directLight * 1.0 - (1.0 - directLight) * 0.6, -1.0, 1.0);
  float warmWeight = smoothstep(-0.25, 0.65, sunExposure) * smoothstep(0.20, 0.75, warmGlazeField) * uDaylightFactor;
  float coolWeight = smoothstep(0.25, -0.65, sunExposure) * smoothstep(0.20, 0.75, coolGlazeField) * uDaylightFactor;

  // 6. Luminous Watercolor Paper Reserve (Dry Brush on Sunlit Crests)
  float paperReserve = smoothstep(0.60, 1.02, crest) *
      smoothstep(0.45, 1.0, illumination) *
      smoothstep(0.20, 0.70, 1.0 - washDensity) *
      stylePaperReserveMult;

  // 7. Cold-Pressed Watercolor Paper Tooth & Pigment Granulation
  float paperFibers = noise(fragCoord * 0.22) * 0.65 + noise(fragCoord * 0.45) * 0.35;
  float paperTooth = hash(fragCoord * 1.6) - 0.5;
  float paperGrain = mix(paperFibers, paperTooth, styleGrainMix);

  // 8. Effective Pigment Concentration across the Paper (Balanced watercolor lazure)
  // Direct sun dissolves pigment into luminous paper base; shadows allow deep mineral settling
  float shadowDeepening = (1.0 - illumination);
  float effectivePigment = clamp(
      0.04 +
      washDensity * 0.35 +
      shadowDeepening * 0.42 +
      innerCrease * styleCreasePool +
      outerCrease * 0.16 -
      paperReserve * 1.2 +
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

  // Apply Cool Glaze Bloom on the shadow side
  washColor = mix(washColor, uColorGlaze.rgb, coolWeight * 0.32);

  // Apply Warm Glaze Bloom on the sunlit side
  washColor = mix(washColor, uColorShelf.rgb, warmWeight * 0.30);

  // Diurnal chromatic warmth
  // Morning/evening: warm golden/rose amber rays
  // Noon: brilliant solar gold
  // Night: cool silvery blue-indigo moonlight
  vec3 diurnalTint = mix(
    vec3(0.88, 0.93, 1.06), // moonlight
    mix(
      vec3(1.09, 0.95, 0.80), // low-angle dawn/dusk golden hour
      vec3(1.02, 1.01, 0.98), // high noon solar zenith
      smoothstep(0.12, 0.70, max(0.0, uSunAltitude))
    ),
    uDaylightFactor
  );
  washColor *= diurnalTint;

  // Tactile paper tooth modulation
  washColor += vec3((paperGrain - 0.5) * styleToothDepth);

  // Path geometry and anti-aliasing are cleanly handled by Skia's canvas.drawPath
  fragColor = vec4(clamp(washColor, 0.0, 1.0), 1.0);
}
