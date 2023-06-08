
#include "surface.glsl"
#include "sdf.glsl"



Surface sdfScene(vec3 p, float time)
{
	Surface sphere = Surface(
		sdfSphere(p - vec3(0.0, 2.4 + 2.0*sin(time/1.0), 0.0), 1.4),
		vec3(0.0, 0.0, 0.0),
		0.1, 32.0,
		0.4,
		0.6, 1.4
	);
	
	Surface octa = Surface(
		sdfOctahedron(repeatXZ(p, 6.0, 6.0) - vec3(0.0, 1.0, 0.0), 1.0) - 0.15,
		vec3(1.0, 0.2, 0.0),
		0.5, 32.0,
		0.3,
		0.0, 1.0
	);
	
	Surface plane;
	Surface dimple;
	if (fract(p.x*0.5) < 0.5 != fract(p.z*0.5) < 0.5) {
		plane = Surface(sdfFloor(p, 0.0), vec3(0.6, 0.6, 0.6), 0.1, 8.0, 0.5, 0.0, 1.0);
		dimple = Surface(sdfOctahedron(repeatXZ(p, 6.0, 6.0) - vec3(0.0, 1.0, 0.0), 1.0), vec3(0.6, 0.6, 0.6), 0.1, 8.0, 0.5, 0.0, 1.0);
	} else {
		plane = Surface(sdfFloor(p, 0.0), vec3(0.2, 0.2, 0.2), 0.1, 8.0, 0.5, 0.0, 1.0);
		dimple = Surface(sdfOctahedron(repeatXZ(p, 6.0, 6.0) - vec3(0.0, 1.0, 0.0), 1.0), vec3(0.6, 0.6, 0.6), 0.1, 8.0, 0.5, 0.0, 1.0);
	}
	
	Surface blackhole = Surface(
		sdfSphere(p - vec3(sin(time+1.0)*5.0, 0.0, cos(time+1.0)*5.0), 1.0),
		vec3(0.0, 0.0, 0.0),
		0.0, 32.0,
		0.0,
		0.0, 1.0
	);
	
	// return sphere;
	Surface d = plane;
	d = blendSDiff(d, dimple, 3.0);
	d = blendMin(octa, d);
	d = blendSMin(d, sphere, 1.0);
	 d = blendDiff(d, blackhole);
	return d;
}