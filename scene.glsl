
#include "surface.glsl"
#include "sdf.glsl"



Surface sdfScene(vec3 p, float time)
{
	Surface sphere = Surface(
		sdfSphere(p - vec3(0.0, 2.0, 0.0), 1.0),
		vec3(0.0),
		0.1, 8.0,
		0.1,
		1.0, 1.6
	);
	
	Surface sphere2a = Surface(
		sdfSphere(p - vec3(2.02, 2.0, 0.0), 2.0),
		vec3(0.0),
		0.1, 8.0,
		0.1,
		1.0, 1.6
	);
	
	Surface sphere2b = Surface(
		sdfSphere(p - vec3(-2.02, 2.0, 0.0), 2.0),
		vec3(0.0),
		0.1, 8.0,
		0.1,
		1.0, 1.6
	);
	
	float ref = sin(time) / 2.0 + 0.5;
	
	Surface plane;
	if (fract(p.x*0.5) < 0.5 != fract(p.z*0.5) < 0.5)
		plane = Surface(sdfFloor(p, 0.0), vec3(0.3), 0.1, 8.0, 0.0, 0.0, 1.0);
	else
		plane = Surface(sdfFloor(p, 0.0), vec3(0.1), 0.1, 8.0, 0.0, 0.0, 1.0);
	
	Surface d = sphere;
	d = blendDiff(d, sphere2a);
	d = blendDiff(d, sphere2b);
	d = blendMin(d, plane);
	
	// Surface d = plane;
	// d = blendMin(octa, d);
	// d = blendSMax(d, sphere, 1.0);
	// d = blendSDiff(d, sphere, 1.0);
	// d = blendSMin(d, sphere, 1.0);
	return d;
	// return blendSDiff(sphere, plane, 1.0);
}