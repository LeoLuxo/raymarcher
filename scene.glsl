
#include "surface.glsl"
#include "sdf.glsl"



Surface sdfScene(vec3 p, float time)
{
	Surface sphere = Surface(
		sdfSphere(p - vec3(0.0, 2.0 + 2.0*sin(time/1.0), 0.0), 1.0),
		vec3(0.0),
		0.1, 8.0,
		0.1,
		0.9, 1.6
	);
	
	Surface octa = Surface(
		sdfOctahedron(repeatXZ(p, 6.0, 6.0) - vec3(0.0, 1.0, 0.0), 1.0),
		vec3(0.0, 0.3, 1.0),
		0.1, 8.0,
		0.4,
		0.6, 1.6
	);
	
	Surface plane;
	if (fract(p.x*0.5) < 0.5 != fract(p.z*0.5) < 0.5)
		plane = Surface(sdfFloor(p, 0.0), vec3(0.3), 0.1, 8.0, 0.5, 0.0, 0.0);
	else
		plane = Surface(sdfFloor(p, 0.0), vec3(0.1), 0.1, 8.0, 0.5, 0.0, 0.0);
	
	// return sphere;
	Surface d = plane;
	d = blendMin(octa, d);
	d = blendSMin(d, sphere, 1.0);
	// d = blendSDiff(d, sphere, 1.0);
	// d = blendSMin(d, sphere, 1.0);
	return d;
	// return blendSDiff(sphere, plane, 1.0);
}