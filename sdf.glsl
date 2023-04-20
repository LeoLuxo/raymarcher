vec3 repeatXZ(vec3 p, float rx, float rz)
{
	p.xz = vec2(mod(p.x+rx/2.0, rx)-rx/2.0, mod(p.z+rz/2.0, rz)-rz/2.0);
	return p;
}



float sdfFloor(vec3 p, float height)
{
	return p.y - height;
}

float sdfFloorThick(vec3 p, float height, float thickness)
{
	return abs(p.y - height) - thickness;
}

float sdfSphere(vec3 p, float radius)
{
	return length(p) - radius;
}

float sdfOctahedron(vec3 p, float size)
{
	p = abs(p);
	float m = p.x+p.y+p.z-size;
	vec3 q;
			if( 3.0*p.x < m ) q = p.xyz;
	else if( 3.0*p.y < m ) q = p.yzx;
	else if( 3.0*p.z < m ) q = p.zxy;
	else return m*0.57735027;
		
	float k = clamp(0.5*(q.z-q.y+size),0.0,size); 
	return length(vec3(q.x,q.y-size+k,q.z-k)); 
}