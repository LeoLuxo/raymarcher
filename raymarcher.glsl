
#define EPSILON 0.00001
#define MIN_MARCH 0.2
#define MAX_MARCH 150.0
#define MAX_MARCH_STEPS 1024

#define SHADOW_DEF 16.0
#define SHADOW_EPSILON 0.001
#define SHADOW_MIN_MARCH 0.01
#define SHADOW_MAX_MARCH 50.0
#define SHADOW_MAX_MARCH_STEPS 256
#define SHADOW_MARCH_BIAS 0.5
#define SHADOW_NORMAL_OFFSET 0.0001

#define AO_STEPS 5
#define AO_STEP_SIZE 0.20
#define AO_MIN_STEP 0.01
#define AO_FALLOFF 0.98

#define SUN_DIR normalize(vec3(1.0, 0.5, 0.0)) // Is inverted, so vector looking TOWARDS the sun
#define SUN_COLOR vec3(8.1, 6.0, 4.2)*0.3
#define SKY_COLOR vec3(0.4, 0.7, 1.0)
#define SKY_FILL_COLOR vec3(0.5, 0.7, 1.0)
#define BOUNCE_COLOR vec3(0.5, 0.5, 0.5)

#define FOG_DISTANCE MAX_MARCH
#define FOG_FADE_DISTANCE 50.0
#define FOG_POWER 0.5

#define REFLECTION_PASSES 2
#define REFLECTION_NORMAL_OFFSET 0.0001


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
	Surface sphere = Surface(
		sdfSphere(p - vec3(0.0, 2.0 + 2.0*sin(time/1.0), 0.0), 1.0),
		vec3(1.0, 0.01, 0.0),
		0.1, 64.0,
		1.0
	);
	
	Surface octa = Surface(
		sdfOctahedron(repeatXZ(p, 6.0, 6.0) - vec3(0.0, 1.0, 0.0), 1.0),
		vec3(0.0, 0.3, 1.0),
		0.5, 8.0,
		0.0
	);
	
	Surface plane;
	if (fract(p.x*0.5) < 0.5 != fract(p.z*0.5) < 0.5)
		plane = Surface(sdfFloor(p, 0.0), vec3(0.7, 0.7, 0.7), 0.1, 8.0, 0.5);
	else
		plane = Surface(sdfFloor(p, 0.0), vec3(0.2, 0.2, 0.2), 0.1, 8.0, 0.5);
	
	// return sphere;
	Surface d = plane;
	d = blendSMin(octa, d, 1.0);
	d = blendSMin(d, sphere, 1.0);
	// d = blendSDiff(d, sphere, 1.0);
	// d = blendSMin(d, sphere, 1.0);
	return d;
	// return blendSDiff(sphere, plane, 1.0);
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

float calcShadow(vec3 rayOrigin, vec3 rayDir, float time)
{
	float t = SHADOW_MIN_MARCH;
   float shadow = 1.0;
	
	for (int i = 0; i < SHADOW_MAX_MARCH_STEPS && t < SHADOW_MAX_MARCH; i++)
	{
		vec3 p = rayOrigin + rayDir * t;
		float h = sdfScene(p, time).dist;
		
		if (h < SHADOW_EPSILON)
			return 0.0;
		
		shadow = min(shadow, SHADOW_DEF * h / t);
		
		t += h * SHADOW_MARCH_BIAS;
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
	float time = 5.0 + iTime * 1.0;
	vec2 mouse = iMouse.xy / iResolution.xy;
	
	vec3 target = vec3(0.0, 8.0*mouse.y - 2.0, 0.0);
	vec3 rayOrigin = vec3(0.0, 2.0, 0.0);
	
	// SUN_DIR = normalize(vec3(cos(time * 0.1), 0.3, sin(time * 0.1)));
	
	// camera.xz = target.xz + vec2(4.5*cos(0.5*time + mouse.x), 4.5*sin(0.5*time + mouse.x));
	rayOrigin.xz = target.xz + vec2(4.5*cos(10.0*mouse.x), 4.5*sin(10.0*mouse.x));
	mat3 viewMat = cameraLookAt(rayOrigin, target);
	
	vec2 uv = (fragCoord - iResolution.xy / 2.0)/iResolution.y;
	float focalLength = 1.0 / 2.0 / 0.5; // tan(45° / 2) = 0.5
	
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
			
			float shadow = calcShadow(hitPoint + normal*SHADOW_NORMAL_OFFSET, SUN_DIR, time);
			float ao = calcAmbientOcclusion(hitPoint, normal, time);
			
			float sunDiffuse = clamp(dot(normal, SUN_DIR), 0.0, 1.0);
			float skyDiffuse = clamp(0.5 + 0.5*dot(normal, vec3(0.0,1.0,0.0)), 0.0, 1.0);
			float bounceDiffuse = clamp(-0.05 + 0.3*dot(normal, vec3(0.0,-1.0,0.0)), 0.0, 1.0);
			
			vec3 lighting = vec3(0.0);
			
			// Sun diffuse
			lighting += SUN_COLOR * sunDiffuse * shadow;
			// Sky ambient diffuse
			lighting += SKY_FILL_COLOR * skyDiffuse * ao;
			// Bounce ambient diffuse
			lighting += BOUNCE_COLOR * bounceDiffuse * ao;
			
			passColor = surf.color * lighting;
			
			// Sun specular
			passColor += SUN_COLOR * surf.specularCoeff * clamp(dot(normal, normalize(rayDir+SUN_DIR)), 0.0, 1.0);
			
			// fog
			// color = mix(color, SKY_COLOR, 1.0-exp(-1e-6*t*t*t));
			passColor = mix(passColor, SKY_COLOR, pow(clamp((t - FOG_DISTANCE + FOG_FADE_DISTANCE)/(FOG_DISTANCE - FOG_FADE_DISTANCE), 0.0, 1.0), FOG_POWER));
			
			
			// Prepare next reflective bounce
			rayOrigin = hitPoint + normal * REFLECTION_NORMAL_OFFSET;
			rayDir = reflect(rayDir, normal);
		}
		else
		{
			// sky color
			passColor = SKY_COLOR - 0.6*max(rayDir.y, 0.0);
			
			// sun
			passColor = passColor + pow(max(dot(SUN_DIR, rayDir)-0.9, 0.0)/0.1, 40.0) * SUN_COLOR;
			
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