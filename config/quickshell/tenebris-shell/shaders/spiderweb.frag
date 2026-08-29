#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float webTime;
    float build;
    float fracture;
    vec2 resolution;
    float webSeed;
    float densityControl;
    float windControl;
    float motionControl;
    vec2 webCenter;
    float spokeControl;
    float ringControl;
    float windAngleControl;
    float startSectorControl;
    float directionControl;
};

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;

float hash11(float value) {
    value = fract(value * 0.1031);
    value *= value + 33.33;
    value *= value + value;
    return fract(value);
}

float hash21(vec2 point) {
    vec3 point3 = fract(vec3(point.xyx) * 0.1031);
    point3 += dot(point3, point3.yzx + 33.33);
    return fract((point3.x + point3.y) * point3.z);
}

vec2 hash22(vec2 point) {
    return vec2(
        hash21(point + vec2(17.17, 41.73)),
        hash21(point + vec2(83.11, 12.53))
    );
}

float valueNoise(vec2 point) {
    vec2 cell = floor(point);
    vec2 local = fract(point);
    local = local * local * (3.0 - 2.0 * local);
    float a = hash21(cell);
    float b = hash21(cell + vec2(1.0, 0.0));
    float c = hash21(cell + vec2(0.0, 1.0));
    float d = hash21(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float silkLine(float distanceToLine, float coreWidth) {
    float antialias = max(fwidth(distanceToLine) * 1.12, 0.00028);
    float core = 1.0 - smoothstep(coreWidth, coreWidth + antialias, distanceToLine);
    float halo = 1.0 - smoothstep(
        coreWidth + antialias,
        coreWidth + antialias * 3.1,
        distanceToLine
    );
    return core + halo * 0.18;
}

float orbWeb(
    vec2 screenPoint,
    vec2 center,
    float coverageRadius,
    float reveal,
    float breakAmount,
    out float activeFront
) {
    vec2 point = (screenPoint - center) / max(coverageRadius, 0.01);
    float restingRadius = length(point);

    // The hub remains pinned. Wind displacement grows towards the capture
    // spiral so the web stretches like one connected elastic structure.
    vec2 windDirection = vec2(cos(windAngleControl), sin(windAngleControl));
    vec2 windNormal = vec2(-windDirection.y, windDirection.x);
    float windScale = clamp(windControl / 1.5, 0.0, 2.0);
    float motionScale = clamp(motionControl / 1.5, 0.0, 2.0);
    float flexStrength = windScale * (0.52 + motionScale * 0.48);
    float gust = sin(webTime * 0.43 + webSeed * 0.031) * 0.67
        + sin(webTime * 0.91 + webSeed * 0.019) * 0.23
        + sin(webTime * 1.57 + webSeed * 0.007) * 0.10;
    float elasticBase = smoothstep(0.035, 1.0, restingRadius);
    float elasticity = elasticBase * sqrt(elasticBase);
    float crossSection = dot(point, windNormal);
    point -= windDirection * gust * flexStrength * elasticity * 0.052;
    point -= windDirection * crossSection * gust * flexStrength * elasticity * 0.034;
    point += windNormal
        * sin(webTime * 0.56 + restingRadius * 7.1 + crossSection * 3.4 + webSeed * 0.011)
        * motionScale * windScale * elasticity * 0.021;
    point += windDirection
        * sin(webTime * 0.34 + restingRadius * 10.3 - crossSection * 2.2)
        * motionScale * windScale * elasticity * restingRadius * 0.010;

    // Input scatters whole sections along the wind while nearby sections
    // retain slightly different inertia.
    float tearCell = hash21(floor(point * 7.0) + webSeed * 0.017);
    float tear = smoothstep(tearCell * 0.66, min(1.0, tearCell * 0.66 + 0.25), breakAmount);
    point -= windDirection * tear * tear * mix(0.05, 0.54, tearCell);
    point += windNormal * tear * sin(tearCell * TAU + breakAmount * PI) * 0.075;

    float radius = length(point);
    float angle = atan(point.y, point.x);
    float spokeCount = spokeControl;
    float ringCount = ringControl;

    // A few low-cost harmonics keep the web handmade without turning it into
    // disconnected procedural noise.
    float irregularAngle = angle
        + sin(angle * 3.0 + webSeed * 0.013) * 0.026
        + sin(angle * 7.0 - webSeed * 0.009) * 0.010
        + sin(radius * 7.0 + webTime * 0.29 + angle * 2.0)
            * motionScale * windScale * elasticity * 0.013;
    float sectorPosition = fract((irregularAngle + PI) / TAU * spokeCount);
    float spokePhase = sectorPosition * PI;

    // Structural spokes are laid from the hub outwards before the capture
    // rings reach them, matching the order in which an orb web is constructed.
    float nearestSpoke = radius * abs(sin(spokePhase));
    float spokeAdvance = clamp(reveal * 1.55 + 0.035, 0.0, 1.04);
    float spokeReveal = 1.0 - smoothstep(spokeAdvance - 0.018, spokeAdvance + 0.035, radius);
    float sector = floor((irregularAngle + PI) / TAU * spokeCount);
    float spokeLife = hash21(vec2(sector, webSeed * 0.021));
    float spokeSurvival = 1.0 - smoothstep(
        spokeLife * 0.74,
        min(1.0, spokeLife * 0.74 + 0.23),
        breakAmount
    );
    float spokes = silkLine(nearestSpoke, 0.00056 + radius * 0.00016)
        * spokeReveal * spokeSurvival;

    // Capture threads sag inward between adjacent spokes. Each ring is born
    // after the previous one, then its stroke travels around the web instead
    // of every ring simply fading in at once.
    float ringEstimate = clamp(radius * ringCount, 0.0, ringCount);
    float ringBand = floor(ringEstimate + 0.5);
    float normalizedRing = ringBand / ringCount;
    float segmentVariation = mix(
        0.82,
        1.20,
        hash21(vec2(sector, ringBand) + webSeed * 0.015)
    );
    float sagBase = max(0.0, sin(spokePhase));
    float sagShape = sagBase * sqrt(sagBase);
    float livingSag = sin(
        webTime * 0.72 + normalizedRing * 9.3 + sector * 1.17 + webSeed * 0.009
    ) * flexStrength * normalizedRing * 0.0065;
    float sag = (0.005 + normalizedRing * 0.017 + livingSag)
        * sagShape * segmentVariation;
    float ageWarp = (valueNoise(vec2(irregularAngle * 2.2, ringBand * 0.37) + webSeed * 0.01) - 0.5)
        * (0.0018 + normalizedRing * 0.0024);
    float warpedRadius = radius + sag + ageWarp;
    float nearestRing = floor(warpedRadius * ringCount + 0.5) / ringCount;
    float ringDistance = abs(warpedRadius - nearestRing);

    float ringStep = 0.875 / ringCount;
    float ringBirth = 0.055 + ringBand * ringStep;
    float ringStroke = clamp((reveal - ringBirth) / (ringStep * 0.78), 0.0, 1.0);
    float canonicalSector = mod(sector + spokeCount, spokeCount);
    float ringDirection = directionControl * mix(-1.0, 1.0, mod(ringBand, 2.0));
    float forwardOrder = mod(canonicalSector - startSectorControl + spokeCount, spokeCount);
    float reverseOrder = mod(startSectorControl - canonicalSector + spokeCount, spokeCount);
    float sectorOrder = mix(reverseOrder, forwardOrder, step(0.0, ringDirection));
    float sectorBirth = sectorOrder / spokeCount;
    float angularReveal = smoothstep(sectorBirth, sectorBirth + 0.022, ringStroke);

    vec2 segmentId = vec2(sector, ringBand) + webSeed * vec2(0.017, 0.029);
    float ringLife = hash21(segmentId);
    float ringSurvival = 1.0 - smoothstep(
        ringLife * 0.70,
        min(1.0, ringLife * 0.70 + 0.20),
        breakAmount
    );
    float rings = silkLine(ringDistance, 0.00064 + normalizedRing * 0.00018)
        * angularReveal * ringSurvival;
    float junction = (1.0 - smoothstep(
        0.00072,
        0.00205,
        max(nearestSpoke, ringDistance)
    )) * angularReveal * ringSurvival * spokeSurvival;

    // The first visible mark is a tight central knot; afterwards the active
    // drawing front travels ring-by-ring towards every screen edge.
    float hubRing = silkLine(abs(radius - 0.021), 0.00084)
        * smoothstep(0.006, 0.040, reveal);
    float hubCore = (1.0 - smoothstep(0.006, 0.018, radius))
        * smoothstep(0.0, 0.025, reveal);
    activeFront = 1.0 - smoothstep(0.0, 0.052, abs(reveal - ringBirth));

    float outerFade = 1.0 - smoothstep(1.005, 1.035, radius);
    float grain = 0.80 + 0.20 * hash21(floor(point * 76.0) + webSeed * 0.006);
    return min(1.7, spokes * 0.60 + rings * 1.05 + junction * 0.72 + hubRing + hubCore * 0.72)
        * outerFade * grain;
}

void main() {
    float aspect = max(0.01, resolution.x / max(1.0, resolution.y));
    vec2 point = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    vec2 center = webCenter * vec2(aspect, 1.0);

    // Deriving the radius from the farthest corner guarantees that this one
    // web reaches the edge on 16:10 and ultrawide displays alike.
    float coverageRadius = length(vec2(
        aspect * 0.5 + abs(center.x),
        0.5 + abs(center.y)
    )) * 1.012;

    float reveal = clamp(build, 0.0, 1.0);
    float activeFront = 0.0;
    float web = orbWeb(point, center, coverageRadius, reveal, fracture, activeFront);
    float density = web * densityControl;

    float blackout = smoothstep(0.88, 1.0, reveal);
    float dust = 0.5;
    if (blackout < 0.999)
        dust = valueNoise(point * 5.2 + vec2(webSeed * 0.008, webTime * 0.012));
    float screenRadius = length((point - center) / vec2(aspect, 1.0));
    float departure = 1.0 - smoothstep(0.70, 1.0, fracture);
    float veilGrowth = smoothstep(0.0, 0.20, reveal);
    float veilAlpha = (0.018 + veilGrowth * (0.255 + screenRadius * 0.055))
        * mix(0.90, 1.08, dust) * departure * (1.0 - blackout);
    float silkAlpha = clamp(density * (0.34 + activeFront * 0.08), 0.0, 0.80) * departure;
    float totalAlpha = clamp(veilAlpha + silkAlpha, 0.0, 0.90);

    vec3 veil = mix(vec3(0.008, 0.009, 0.010), vec3(0.023, 0.024, 0.025), dust)
        * veilAlpha;
    vec3 oldSilk = vec3(0.43, 0.44, 0.43);
    vec3 freshSilk = vec3(0.93, 0.94, 0.91);
    vec3 silk = mix(oldSilk, freshSilk, clamp(density * 0.48 + activeFront * 0.18, 0.0, 1.0))
        * silkAlpha;
    vec3 premultiplied = min(veil + silk, vec3(totalAlpha));
    fragColor = vec4(premultiplied, totalAlpha) * qt_Opacity;
}
