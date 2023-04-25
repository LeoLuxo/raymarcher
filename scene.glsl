
#include "surface.glsl"
#include "sdf.glsl"



Surface sdfScene(vec3 p, float time)
{
	float wallReflec = 0.2;
	
	Surface ceilingHole = Surface(sdfBox(p - vec3(0.0, 10.0, 0.0), vec3(2.0, 2.0, 2.0)), vec3(1.0), 0.0, 0.0, 1.0, 0.0, 1.0);
	Surface ceilingWall = Surface(sdfBox(p - vec3(0.0, 11.0, 0.0), vec3(12.0, 2.0, 12.0)), vec3(0.9), 0.1, 16.0, wallReflec, 0.0, 1.0);
	
	Surface floorWall;
	if (fract(p.x*0.5) < 0.5 != fract(p.z*0.5) < 0.5)
		floorWall = Surface(sdfBox(p - vec3(0.0, -1.0, 0.0), vec3(12.0, 2.0, 12.0)), vec3(0.7), 0.1, 16.0, wallReflec, 0.0, 1.0);
	else
		floorWall = Surface(sdfBox(p - vec3(0.0, -1.0, 0.0), vec3(12.0, 2.0, 12.0)), vec3(0.9), 0.1, 16.0, wallReflec, 0.0, 1.0);
	
	Surface backWall = Surface(sdfBox(p - vec3(0.0, 5.0, 5.5), vec3(12.0, 11.0, 1.0)), vec3(0.9), 0.1, 16.0, wallReflec, 0.0, 1.0);
	Surface rightWall = Surface(sdfBox(p - vec3(-5.5, 5.0, 0), vec3(1.0, 11.0, 12.0)), vec3(0.0, 0.3, 0.9), 0.1, 16.0, wallReflec, 0.0, 1.0);
	Surface leftWall = Surface(sdfBox(p - vec3(5.5, 5.0, 0), vec3(1.0, 11.0, 12.0)), vec3(0.9, 0.3, 0.0), 0.1, 16.0, wallReflec, 0.0, 1.0);
	
	
	
	Surface sphere1 = Surface(
		sdfSphere(p - vec3(3.0, 2.0, 1.0), 2.0),
		vec3(0.0),
		0.1, 16.0,
		1.0,
		0.0, 1.0
	);
	
	Surface sphere2 = Surface(
		sdfSphere(p - vec3(-3.0, 5.0, -1.0), 1.0),
		vec3(0.0),
		0.1, 16.0,
		0.1,
		0.9, 1.6
	);
	
	Surface d = floorWall;
	d = blendMin(d, ceilingWall);
	d = blendDiff(d, ceilingHole);
	d = blendMin(d, backWall);
	d = blendMin(d, rightWall);
	d = blendMin(d, leftWall);
	
	d = blendMin(d, sphere1);
	d = blendMin(d, sphere2);
	
	return d;
}