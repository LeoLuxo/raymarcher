
#include "surface.glsl"
#include "sdf.glsl"

// Precision-adjusted variations of https://www.shadertoy.com/view/4djSRW
float hash(float p) { p = fract(p * 0.011); p *= p + 7.5; p *= p + p; return fract(p); }
float hash(vec2 p) {vec3 p3 = fract(vec3(p.xyx) * 0.13); p3 += dot(p3, p3.yzx + 3.333); return fract((p3.x + p3.y) * p3.z); }


float noise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);

	// Four corners in 2D of a tile
	float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    // Simple 2D lerp using smoothstep envelope between the values.
	// return vec3(mix(mix(a, b, smoothstep(0.0, 1.0, f.x)),
	//			mix(c, d, smoothstep(0.0, 1.0, f.x)),
	//			smoothstep(0.0, 1.0, f.y)));

	// Same code, with the clamps in smoothstep and common subexpressions
	// optimized away.
    vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

Surface sdfScene(vec3 p, float time) {
	
	time *= 0.5;
	
	float layer1 = noise(p.xz*2.0 + vec2(time*2.0, time*3.0)*0.2) * 1.0;
	float layer2 = noise(p.xz*3.2 + vec2(time*-1.1, time*2.0)*0.3) * 0.5;
	float layer3 = noise(p.xz*4.0 + vec2(time*4.0, time*2.0)*0.5) * 0.2;

	Surface water = Surface(sdfFloorThick(p, 0.0, 0.1 + 0.2*(layer1+layer2+layer3)), vec3(0.0, 0.03, 0.1), 0.0, 0.0, 0.1, 0.9, 1.6);
	
	return water;
}