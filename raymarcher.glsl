
#define EPSILON 0.0001
#define MIN_MARCH 0.05
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

#define SUN_DIR normalize(vec3(-0.8, 0.5, -1.0)) // Is inverted, so vector looking TOWARDS the sun
#define SUN_COLOR vec3(8.1, 6.0, 4.2)*0.3
#define SKY_COLOR vec3(0.4, 0.7, 1.0)
#define SKY_FILL_COLOR vec3(0.5, 0.7, 1.0)
#define BOUNCE_COLOR vec3(0.5, 0.5, 0.5)

#define FOG_DISTANCE MAX_MARCH
#define FOG_FADE_DISTANCE 50.0
#define FOG_POWER 0.5

#define RECURSION_PASSES 6
#define RECURSION_NORMAL_OFFSET 0.001


#iChannel0 "file://skybox/{}.jpg"
#iChannel0::Type "CubeMap"


#include "scene.glsl"






Surface rayMarch(vec3 rayOrigin, vec3 rayDir, float invert, float time)
{
	int i;
	float t = MIN_MARCH;
	Surface outSurf;
	
	for (i = 0; i < MAX_MARCH_STEPS && t < MAX_MARCH; i++)
	{
		vec3 p = rayOrigin + rayDir * t;
		outSurf = sdfScene(p, time);
		outSurf.dist = invert * outSurf.dist;
		
		if (outSurf.dist < EPSILON) break;
		
		t += outSurf.dist;
	}
	
	if (t >= MAX_MARCH)
		t = -1.0;
	
	// outSurf.color = vec3(float(i) / float(MAX_MARCH_STEPS));
	
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
   float shadow = 1.0;
	
	for (int i = 0; i < SHADOW_MAX_MARCH_STEPS && t < SHADOW_MAX_MARCH; i++)
	{
		t += h * SHADOW_MARCH_BIAS;
		t = min(t, maxDist);
		
		vec3 p = rayOrigin + rayDir * t;
		h = sdfScene(p, time).dist;
		
		if (h < SHADOW_EPSILON)
			return 0.0;
		
		shadow = min(shadow, SHADOW_DEF * h / t);
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


vec3 calcPassColor(Surface surf, vec3 hitPoint, vec3 rayDir, vec3 normal, float t, float invert, float time) {
	
	vec3 passColor = vec3(0.0);
	
	if (t >= 0.0)
	{
		
		if (true) {
			float shadow = calcShadow(hitPoint + normal*SHADOW_NORMAL_OFFSET, SUN_DIR, 1000.0, time);
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
		} else {
			passColor = surf.color;
		}
	}
	else
	{
		// sky color
		// passColor = SKY_COLOR - 0.6*max(rayDir.y, 0.0);
		passColor = texture(iChannel0, rayDir).rgb;
		
		// sun
		passColor = passColor + pow(max(dot(SUN_DIR, rayDir)-0.9, 0.0)/0.1, 40.0) * SUN_COLOR;
	}
	
	return passColor;
}


vec3 render(in vec2 fragCoord)
{
	float time = 1.0 + iTime * 0.1;
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
	
	float bounceCoeff = 1.0;
	bool bounceType = false; // false = reflection, true = refraction
	float invert = 1.0;
	
	for (int bounce=0; bounce < RECURSION_PASSES; bounce++)
	{
		Surface surf = rayMarch(rayOrigin, rayDir, invert, time);
		float t = surf.dist;
		
		bounceType = surf.refractionCoeff > surf.reflectionCoeff;
		
		
		// assuming object was hit (otherwise we don't care about the values)
		vec3 hitPoint = rayOrigin + rayDir * t;
		vec3 normal = calcNormal(hitPoint, time);
		
		vec3 passColor = calcPassColor(surf, hitPoint, rayDir, normal, t, invert, time);
		
		// Add pass color to final color
		color += passColor * bounceCoeff;
		
		if (t >= 0.0) {
			// Prepare next reflective bounce
			rayOrigin = hitPoint + normal * RECURSION_NORMAL_OFFSET * invert;
			
			if (bounceType) {
				if (invert > 0.0)
					rayDir = refract(rayDir, normal, 1.0 / surf.refractionIndex);
				else
					rayDir = refract(rayDir, -normal, surf.refractionIndex);
				bounceCoeff = bounceCoeff * surf.refractionCoeff;
				invert = -invert;
			} else {
				rayDir = reflect(rayDir, normal);
				bounceCoeff = bounceCoeff * surf.reflectionCoeff;
			}
			
		} else {
			// No more recursion afterwards
			break;
		}
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