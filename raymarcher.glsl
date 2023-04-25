
#define EPSILON 0.0001
#define MIN_MARCH 0.05
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

// #define ANIMATED_LIGHT
#define LIGHT_COLOR vec3(0.8)
#define AMBIENT_COLOR (vec3(1.0) - LIGHT_COLOR)


#define RECURSION_MAX_PASSES 16
#define RECURSION_NORMAL_OFFSET 0.001

// #define ANIMATED_LIGHT


#iChannel0 "file://skybox/{}.jpg"
#iChannel0::Type "CubeMap"


#include "scene.glsl"


struct RenderPass {
	float blendCoeff;
	vec3 rayOrigin;
	vec3 rayDir;
	float invert;
};

struct RenderPassResult {
	Surface hitSurface;
	bool hit;
	vec3 hitPoint;
	vec3 normal;
	vec3 rayDir;
};



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

RenderPassResult calcPass(RenderPass pass, float time) {
	RenderPassResult result;
		
	result.hitSurface = rayMarch(pass.rayOrigin, pass.rayDir, pass.invert, time);
	
	result.hit = result.hitSurface.dist >= 0.0;
	
	// assuming object was hit (otherwise we don't care about the values)
	result.hitPoint = pass.rayOrigin + pass.rayDir * result.hitSurface.dist;
	result.normal = calcNormal(result.hitPoint, time);
	
	result.rayDir = pass.rayDir;
	
	return result;
}

vec3 skyColor(vec3 rayDir) {
	// skybox
	vec3 skyColor = texture(iChannel0, rayDir).rgb;
	
	return skyColor;
}

vec3 calcPassColor(RenderPassResult pass, vec3 light, float time) {
	
	vec3 passColor = skyColor(pass.rayDir);
	
	if (pass.hit)
	{
		vec3 lightDir = normalize(light - pass.hitPoint);
		
		
		float shadow = calcShadow(pass.hitPoint + pass.normal*SHADOW_NORMAL_OFFSET, lightDir, distance(light, pass.hitPoint), time);
		float ao = calcAmbientOcclusion(pass.hitPoint, pass.normal, time);
		
		float lightDiffuse = clamp(dot(pass.normal, lightDir), 0.0, 1.0);
		
		vec3 lighting = vec3(0.0);
			
		// light diffuse
		lighting += LIGHT_COLOR * lightDiffuse * shadow;
		// ambient
		lighting += AMBIENT_COLOR * ao;
		
		passColor = pass.hitSurface.color * lighting;
		
		// Light specular
		passColor += LIGHT_COLOR * pass.hitSurface.specularCoeff * clamp(dot(pass.normal, normalize(pass.rayDir+lightDir)), 0.0, 1.0);
	}
	
	return passColor;
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
	
	int queuedPasses = 1;
	RenderPass passes[RECURSION_MAX_PASSES];
	passes[0] = RenderPass(1.0, rayOrigin, rayDir, 1.0);
	
	for (int bounce=0; bounce < RECURSION_MAX_PASSES || bounce < queuedPasses; bounce++)
	{
		RenderPass currentPass = passes[bounce];
		RenderPassResult result = calcPass(currentPass, time);
		
		#ifdef ANIMATED_LIGHT
		vec3 light = vec3(4.0*sin(time), 5.0 + 4.0*cos(time), 3.0*sin(time-1.0));
		#else
		vec3 light = vec3(10.0 - 20.0 * mouse.x, -5.0 + 20.0 * mouse.y, 0.0);
		#endif
			
		
		vec3 passColor = calcPassColor(result, light, time);
		
		// Add pass color to final color
		color += passColor * currentPass.blendCoeff;
		
		if (result.hit) {
			// Prepare next reflective & refractive bounces
			
			if (result.hitSurface.reflectionCoeff > 0.0 && queuedPasses < RECURSION_MAX_PASSES) {
				RenderPass reflectionPass;
				reflectionPass.blendCoeff = currentPass.blendCoeff * result.hitSurface.reflectionCoeff;
				reflectionPass.rayDir = reflect(currentPass.rayDir, result.normal);
				reflectionPass.invert = currentPass.invert;
				reflectionPass.rayOrigin = result.hitPoint + result.normal * RECURSION_NORMAL_OFFSET * reflectionPass.invert;
				
				passes[queuedPasses] = reflectionPass;
				queuedPasses++;
			}
			
			if (result.hitSurface.refractionCoeff > 0.0 && queuedPasses < RECURSION_MAX_PASSES) {
				RenderPass refractionPass;
				refractionPass.blendCoeff = currentPass.blendCoeff * result.hitSurface.refractionCoeff;
				if (currentPass.invert > 0.0)
					refractionPass.rayDir = refract(currentPass.rayDir, result.normal, 1.0 / result.hitSurface.refractionIndex);
				else
					refractionPass.rayDir = refract(currentPass.rayDir, -result.normal, result.hitSurface.refractionIndex);
				refractionPass.invert = -currentPass.invert;
				refractionPass.rayOrigin = result.hitPoint + result.normal * RECURSION_NORMAL_OFFSET * refractionPass.invert;
				
				passes[queuedPasses] = refractionPass;
				queuedPasses++;
			}
		}
		
		// Continue calculating the next queued passes
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