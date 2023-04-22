
#include "surface.glsl"
#include "sdf.glsl"



Surface sdfScene(vec3 p, float time)
{
	
	// float ref = sin(time) / 2.0 + 0.5;
	
	Surface sphere = Surface(
		sdfSphere(p - vec3(sin(-time * 1.0), 2.0, 0.0), 1.0),
		vec3(0.0),
		0.1, 8.0,
		0.1,
		0.9, 1.6
	);
	
	Surface red = Surface(
		sdfSphere(p - vec3(sin(time * 0.5) * 1.0, 2.0, 0.0), 0.4),
		vec3(1.0, 0.0, 0.0),
		0.1, 8.0,
		0.9,
		0.1, 1.6
	);
	
	Surface red2 = Surface(
		sdfSphere(p - vec3(sin(time * 0.5) * 1.0, 2.0, 0.0), 0.5),
		vec3(1.0, 0.0, 0.0),
		0.1, 8.0,
		0.9,
		0.1, 1.6
	);
	
	Surface plane;
	if (fract(p.x*0.5) < 0.5 != fract(p.z*0.5) < 0.5)
		plane = Surface(sdfFloor(p, 0.0), vec3(0.3), 0.1, 8.0, 0.0, 0.0, 1.0);
	else
		plane = Surface(sdfFloor(p, 0.0), vec3(0.1), 0.1, 8.0, 0.0, 0.0, 1.0);
	
	Surface d = sphere;
	d = blendDiff(d, red2);
	d = blendSMin(d, red, 0.5);
	d = blendMin(d, plane);
	
	// Surface d = plane;
	// d = blendMin(octa, d);
	// d = blendSMax(d, sphere, 1.0);
	// d = blendSDiff(d, sphere, 1.0);
	// d = blendSMin(d, sphere, 1.0);
	return d;
	// return blendSDiff(sphere, plane, 1.0);
}