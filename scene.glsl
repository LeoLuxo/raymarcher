
#include "surface.glsl"
#include "sdf.glsl"



Surface sdfScene(vec3 p, float time)
{
	// Surface sphere = Surface(
	// 	sdfSphere(p - vec3(0.0, 0.0, 0.0), 1.3),
	// 	vec3(1.0, 0.0, 0.0),
	// 	0.2, 256.0,
	// 	0.0,
	// 	0.0, 1.0
	// );
	
	// Surface box = Surface(
	// 	sdfBox(p - vec3(0.0, 0.0, 0.0), vec3(2.0)),
	// 	vec3(0.0, 0.0, 1.0),
	// 	0.2, 256.0,
	// 	0.0,
	// 	0.0, 1.0
	// );
	
	// // return blendMin(sphere, box);
	// return sphere;
	
	Surface sphere = Surface(
		sdfSphere(p - vec3(0.0, 1.0, 0.0), 1.0),
		vec3(1.0, 0.01, 0.0),
		0.1, 64.0,
		0.0,
		0.0, 1.0
	);
	
	Surface plane = Surface(sdfFloor(p, 0.0), vec3(0.7, 0.7, 0.7), 0.1, 8.0, 0.0, 0.0, 1.0);
	
	// return sphere;
	Surface d = plane;
	// d = blendMin(d, sphere);
	// d = blendSDiff(d, sphere, 1.0);
	d = blendSMin(d, sphere, 1.0);
	return d;
	// return blendSDiff(sphere, plane, 1.0);
}