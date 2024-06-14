#include "../surface.glsl"
#include "../sdf.glsl"

void controls(inout float time, out vec2 mouse, out vec3 rayTarget, out vec3 rayOrigin)
{
	mouse = iMouse.xy / iResolution.xy;
	// vec2 mouse = vec2(1.173, 1.0);
	
	target = vec3(0.0, 1.0, 0.0);
	rayOrigin = vec3(0.0, 1.0, 0.0);
	
	// camera.xz = target.xz + vec2(4.5*cos(0.5*time + mouse.x), 4.5*sin(0.5*time + mouse.x));
	rayOrigin.xz = target.xz + vec2(4.5*cos(10.0*mouse.x), 4.5*sin(10.0*mouse.x));
}

Surface sdfScene(vec3 p, float time)
{
	Surface sphere = Surface(
		sdfSphere(p - vec3(0.0, 3.0 + 1.0*sin(1.0+time*0.5), 0.0), 1.0),
		vec3(0.0),
		0.1, 8.0,
		0.4,
		0.6, 1.6
	);
	
	float ref = sin(time) / 2.0 + 0.5;
	
	Surface octa = Surface(
		sdfOctahedron(repeatXZ(p, 6.0, 6.0) - vec3(0.0, 1.0, 0.0), 1.0),
		vec3(0.0, 0.3, 1.0),
		0.1, 8.0,
		ref,
		1.0-ref, 1.6
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