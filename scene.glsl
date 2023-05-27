
#include "surface.glsl"
#include "sdf.glsl"



Surface sdfScene(vec3 p, float time)
{
	Surface sphere = Surface(
		sdfSphere(p - vec3(0.0, 0.0, 0.0), 1.3),
		vec3(1.0, 0.0, 0.0),
		0.0, 8.0,
		0.0,
		0.0, 1.0
	);
	
	Surface box = Surface(
		sdfBox(p - vec3(0.0, 0.0, 0.0), vec3(2.0)),
		vec3(0.0, 0.0, 1.0),
		0.0, 8.0,
		0.0,
		0.0, 1.0
	);
	
	return blendDiff(sphere, box);
}