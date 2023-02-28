
#define EPSILON 0.0001
#define MIN_MARCH 0.1
#define MAX_MARCH 150.0
#define MAX_MARCH_STEPS 1024

#define SHADOW_DEF 8.0
#define SHADOW_EPSILON 0.001
#define SHADOW_MIN_MARCH 0.01
#define SHADOW_MAX_MARCH 50.0
#define SHADOW_MAX_MARCH_STEPS 2000
#define SHADOW_MARCH_BIAS 1.0
#define SHADOW_NORMAL_OFFSET 0.01

#define AO_STEPS 5
#define AO_STEP_SIZE 0.20
#define AO_MIN_STEP 0.01
#define AO_FALLOFF 0.98

#define REFLECTION_PASSES 4
#define REFLECTION_NORMAL_OFFSET 0.0001

// #define ANIMATED_LIGHT


struct Surface {
	float dist;
	vec3 color;
	float specularCoeff;
	float specularPow;
	float reflectionCoeff;
};



vec2 smin(float a, float b, float k)
{
	float h = max(k-abs(a-b), 0.0)/k;
	float m = h*h*h*0.5;
	float s = m*k*(1.0/3.0);
	return (a<b) ? vec2(a-s,m) : vec2(b-s,1.0-m);
}

vec2 smax(float a, float b, float k)
{
	float h = max(k-abs(a-b), 0.0)/k;
	float m = h*h*h*0.5;
	float s = m*k*(1.0/3.0);
	return (a>b) ? vec2(a+s,m) : vec2(b+s,1.0-m);
}

Surface blendMin(Surface a, Surface b)
{
	if (a.dist < b.dist)
		return a;
	else
		return b;
}

Surface blendMax(Surface a, Surface b)
{
	if (a.dist > b.dist)
		return a;
	else
		return b;
}

Surface blendDiff(Surface a, Surface b)
{
	if (a.dist > -b.dist)
		return a;
	else
	{
		b.dist = -b.dist;
		return b;
	}
}

Surface blendSurf(Surface a, Surface b, float blend)
{
	a.color = mix(a.color, b.color, blend);
	a.specularCoeff = mix(a.specularCoeff, b.specularCoeff, blend);
	a.specularPow = mix(a.specularPow, b.specularPow, blend);
	a.reflectionCoeff = mix(a.reflectionCoeff, b.reflectionCoeff, blend);
	return a;
}

Surface blendSMin(Surface a, Surface b, float k)
{
	vec2 blend = smin(a.dist, b.dist, k);
	a.dist = blend.x;
	a = blendSurf(a, b, blend.y);
	return a;
}

Surface blendSMax(Surface a, Surface b, float k)
{
	vec2 blend = smax(a.dist, b.dist, k);
	a.dist = blend.x;
	a = blendSurf(a, b, blend.y);
	return a;
}

Surface blendSDiff(Surface a, Surface b, float k)
{
	vec2 blend = smax(a.dist, -b.dist, k);
	a.dist = blend.x;
	a = blendSurf(a, b, blend.y);
	return a;
}

vec3 repeatXZ(vec3 p, float rx, float rz)
{
	p.xz = vec2(mod(p.x+rx/2.0, rx)-rx/2.0, mod(p.z+rz/2.0, rz)-rz/2.0);
	return p;
}



float sdfFloor(vec3 p, float height)
{
	return p.y - height;
}

float sdfSphere(vec3 p, float radius)
{
	return length(p) - radius;
}

float sdfBox(vec3 p, vec3 bounds)
{
  vec3 q = abs(p) - bounds/2.0;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
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

Surface sdfScene(vec3 p, float time)
{
	float wallReflec = 0.2;
	
	Surface ceilingHole = Surface(sdfBox(p - vec3(0.0, 10.0, 0.0), vec3(2.0, 2.0, 2.0)), vec3(1.0), 0.0, 0.0, 1.0);
	Surface ceilingWall = Surface(sdfBox(p - vec3(0.0, 11.0, 0.0), vec3(12.0, 2.0, 12.0)), vec3(0.9), 0.1, 16.0, wallReflec);
	
	Surface floorWall;
	if (fract(p.x*0.5) < 0.5 != fract(p.z*0.5) < 0.5)
		floorWall = Surface(sdfBox(p - vec3(0.0, -1.0, 0.0), vec3(12.0, 2.0, 12.0)), vec3(0.7), 0.1, 16.0, wallReflec);
	else
		floorWall = Surface(sdfBox(p - vec3(0.0, -1.0, 0.0), vec3(12.0, 2.0, 12.0)), vec3(0.9), 0.1, 16.0, wallReflec);
	
	Surface backWall = Surface(sdfBox(p - vec3(0.0, 5.0, 5.5), vec3(12.0, 11.0, 1.0)), vec3(0.9), 0.1, 16.0, wallReflec);
	Surface rightWall = Surface(sdfBox(p - vec3(-5.5, 5.0, 0), vec3(1.0, 11.0, 12.0)), vec3(0.0, 0.3, 0.9), 0.1, 16.0, wallReflec);
	Surface leftWall = Surface(sdfBox(p - vec3(5.5, 5.0, 0), vec3(1.0, 11.0, 12.0)), vec3(0.9, 0.3, 0.0), 0.1, 16.0, wallReflec);
	
	
	
	Surface sphere1 = Surface(
		sdfSphere(p - vec3(3.0, 2.0, 1.0), 2.0),
		vec3(0.0),
		0.1, 16.0,
		1.0
	);
	
	Surface sphere2 = Surface(
		sdfSphere(p - vec3(-3.0, 5.0, -1.0), 1.0),
		vec3(0.0),
		0.1, 16.0,
		1.0
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






Surface rayMarch(vec3 rayOrigin, vec3 rayDir, float time)
{
	int i;
	float t = MIN_MARCH;
	Surface outSurf;
	
	for (i = 0; i < MAX_MARCH_STEPS && t < MAX_MARCH; i++)
	{
		vec3 p = rayOrigin + rayDir * t;
		outSurf = sdfScene(p, time);
		
		if (outSurf.dist < EPSILON) break;
		
		t += outSurf.dist;
	}
	
	if (t >= MAX_MARCH)
		t = -1.0;
	
	// outSurf.color = float(i) / float(MAX_MARCH_STEPS) * outSurf.color;
	
	outSurf.dist = t;
	
	return outSurf;
}



vec3 calcNormal(vec3 p, float time) // for function f(p)
{
	float h = 0.0001; // replace by an appropriate value
	vec2 k = vec2(1,-1);
	return normalize( k.xyy*sdfScene(p + k.xyy*h, time).dist + 
							k.yyx*sdfScene(p + k.yyx*h, time).dist + 
							k.yxy*sdfScene(p + k.yxy*h, time).dist + 
							k.xxx*sdfScene(p + k.xxx*h, time).dist);
}

float calcShadow(vec3 rayOrigin, vec3 rayDir, float maxDist, float time)
{
	float t = SHADOW_MIN_MARCH;
	float h = 0.0;
	float ph = 1e20;
   float shadow = 1.0;
	
	for (int i = 0; i < SHADOW_MAX_MARCH_STEPS && t < min(SHADOW_MAX_MARCH, maxDist); i++)
	{
		t += h * SHADOW_MARCH_BIAS;
		t = min(t, maxDist);
		
		vec3 p = rayOrigin + rayDir * t;
		h = sdfScene(p, time).dist;
		
		if (h < SHADOW_EPSILON)
			return 0.0;
		
		shadow = min(shadow, SHADOW_DEF * h / t);
		// float y = h*h/(2.0*ph);
		// float d = sqrt(h*h-y*y);
		// shadow = min(shadow, SHADOW_DEF * d/max(0.0, t-y));
		// ph = h;
	}
	
	return clamp(shadow, 0.0, 1.0);
}

float calcAmbientOcclusion(vec3 p, vec3 normal, float time)
{
	float ao = 0.0;
	float falloff = 1.0;
	for(int i = 0; i < AO_STEPS; i++)
	{
		float h = AO_MIN_STEP + AO_STEP_SIZE*float(i)/float(AO_STEPS-1);
		vec3 p2 = p + h * normal;
		float d = sdfScene(p2, time).dist;
		ao += (h-d)*falloff;
		falloff *= AO_FALLOFF;
	}
	return clamp(1.0 - 2.0*ao, 0.0, 1.0);
}



mat3 cameraLookAt(vec3 position, vec3 target)
{
	vec3 fwd = normalize(target - position);
	vec3 right = normalize(cross(fwd, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, fwd);
	return mat3(right, up, fwd);
}


vec3 render(in vec2 fragCoord)
{
	float time = 0.0 + iTime * 1.0;
	vec2 mouse = iMouse.xy / iResolution.xy;
	
	vec3 target = vec3(0.0, 5.0, 0.0);
	vec3 rayOrigin = vec3(0.0, 5.0, -10.0);
	
	mat3 viewMat = cameraLookAt(rayOrigin, target);
	
	vec2 uv = (fragCoord - iResolution.xy / 2.0)/iResolution.y;
	float focalLength = 1.0 / 2.0 / tan(radians(45.0)); // tan(45° / 2) = 0.5
	
	vec3 rayDir = viewMat * normalize(vec3(uv, focalLength));
	
	vec3 color = vec3(0.0);
	float reflection = 1.0;
	
	for (int ref=0; ref < REFLECTION_PASSES; ref++)
	{
		vec3 passColor;
		
		Surface surf = rayMarch(rayOrigin, rayDir, time);
		float t = surf.dist;
		
		if (t >= 0.0)
		{
			// object was hit
			vec3 hitPoint = rayOrigin + rayDir * t;
			vec3 normal = calcNormal(hitPoint, time);
			
			#ifdef ANIMATED_LIGHT
			vec3 light = vec3(4.0*sin(time), 5.0 + 4.0*cos(time), 3.0*sin(time-1.0));
			#else
			vec3 light = vec3(10.0 - 20.0 * mouse.x, -5.0 + 20.0 * mouse.y, 0.0);
			#endif
			
			vec3 lightDir = normalize(light - hitPoint);
			
			vec3 lightColor = vec3(0.8);
			vec3 ambientColor = vec3(1.0) - lightColor;
			
			float shadow = calcShadow(hitPoint + normal*SHADOW_NORMAL_OFFSET, lightDir, distance(light, hitPoint), time);
			float ao = calcAmbientOcclusion(hitPoint, normal, time);
			
			float lightDiffuse = clamp(dot(normal, lightDir), 0.0, 1.0);
			
			vec3 lighting = vec3(0.0);
			
			// light diffuse
			lighting += lightColor * lightDiffuse * shadow;
			// ambient
			lighting += ambientColor * ao;
			
			passColor = surf.color * lighting;
			
			// light specular
			passColor += lightColor * surf.specularCoeff * clamp(dot(normal, normalize(rayDir+lightDir)) * shadow, 0.0, 1.0);
			
			
			// Prepare next reflective bounce
			rayOrigin = hitPoint + normal * REFLECTION_NORMAL_OFFSET;
			rayDir = reflect(rayDir, normal);
		}
		else
		{
			// black background color
			passColor = vec3(0.0);
			
			// No more recursion afterwards (not breaking because we still want to add the pass color)
			ref = REFLECTION_PASSES;
		}
		
		// Add pass color to final color
		color += passColor * reflection;
		
		// Prepare next reflective bounce
		reflection = reflection * surf.reflectionCoeff;
	}
	
	return color;
}


void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec3 color = render(fragCoord);
	
	// gamma correction
	color = pow(color, vec3(0.4545));
	
	fragColor = vec4(color, 1.0);
}