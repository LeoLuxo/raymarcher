
#define EPSILON 0.0001
#define MIN_MARCH 0.005
#define MAX_MARCH 50.0
#define MAX_MARCH_STEPS 2048

#define SHADOW_DEF 16.0
#define SHADOW_EPSILON 0.001
#define SHADOW_MIN_MARCH 0.01
#define SHADOW_MAX_MARCH MAX_MARCH
#define SHADOW_MAX_MARCH_STEPS MAX_MARCH_STEPS
#define SHADOW_MARCH_BIAS 0.5
#define SHADOW_NORMAL_OFFSET 0.0001

#define AO_STEPS 0
#define AO_STEP_SIZE 0.20
#define AO_MIN_STEP 0.01
#define AO_FALLOFF 0.98

#define SUN_DIR normalize(vec3(-0.8, 0.5, -1.0)) // Is inverted, so vector looking TOWARDS the sun
#define SUN_COLOR vec3(8.1, 6.0, 4.2)*0.5
#define SKY_COLOR vec3(0.4, 0.7, 1.0)
#define SKY_FILL_COLOR vec3(0.5, 0.7, 1.0)
#define BOUNCE_COLOR vec3(0.5, 0.5, 0.5)

#define FOG_DISTANCE MAX_MARCH
#define FOG_FADE_DISTANCE 5.0
#define FOG_POWER 0.5

#define RECURSION_MAX_PASSES 16
#define RECURSION_NORMAL_OFFSET 0.0001


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
	return vec3(1.0);
}

vec3 calcPassColor(RenderPassResult pass, float time) {
	
	vec3 passColor = skyColor(pass.rayDir);
	
	if (pass.hit)
	{
		float shadow = calcShadow(pass.hitPoint + pass.normal*SHADOW_NORMAL_OFFSET, SUN_DIR, 1000.0, time);
		float ao = calcAmbientOcclusion(pass.hitPoint, pass.normal, time);
		
		float sunDiffuse = clamp(dot(pass.normal, SUN_DIR), 0.0, 1.0);
		float skyDiffuse = clamp(0.5 + 0.5*dot(pass.normal, vec3(0.0,1.0,0.0)), 0.0, 1.0);
		float bounceDiffuse = clamp(-0.05 + 0.3*dot(pass.normal, vec3(0.0,-1.0,0.0)), 0.0, 1.0);
		
		vec3 lighting = vec3(0.0);
			
		// Sun diffuse
		lighting += SUN_COLOR * sunDiffuse * shadow;
		// Sky ambient diffuse
		lighting += SKY_FILL_COLOR * skyDiffuse * ao;
		// Bounce ambient diffuse
		lighting += BOUNCE_COLOR * bounceDiffuse * ao;
		
		passColor = pass.hitSurface.color * lighting;
		
		// Sun specular
		passColor += SUN_COLOR * pass.hitSurface.specularCoeff * pow(clamp(-dot(pass.normal, normalize(pass.rayDir+SUN_DIR)), 0.0, 1.0), pass.hitSurface.specularPow) * sunDiffuse;
		
		// float spe = pow( clamp( dot( pass.normal, rayDir+SUN_DIR ), 0.0, 1.0 ),16.0);
		// spe *= dif;
		// spe *= 0.04+0.96*pow(clamp(1.0-dot(hal,lig),0.0,1.0),5.0);
	}
	
	return passColor;
}


vec3 render(in vec2 fragCoord)
{
	float time = iTime * 1.0;
	vec2 mouse = iMouse.xy / iResolution.xy;
	// vec2 mouse = vec2(1.173, 1.0);
	
	vec3 target = vec3(0.0, 0.0, 0.0);
	vec3 rayOrigin = vec3(0.0, 2.0, 0.0);
	
	// camera.xz = target.xz + vec2(4.5*cos(0.5*time + mouse.x), 4.5*sin(0.5*time + mouse.x));
	rayOrigin.xz = target.xz + vec2(4.5*cos(10.0*mouse.x), 4.5*sin(10.0*mouse.x));
	mat3 viewMat = cameraLookAt(rayOrigin, target);
	
	vec2 uv = (fragCoord - iResolution.xy / 2.0)/iResolution.y;
	float focalLength = 1.0 / 2.0 / 0.5; // tan(45° / 2) = 0.5
	
	vec3 rayDir = viewMat * normalize(vec3(uv, focalLength));
	
	vec3 color = vec3(0.0);
	
	int queuedPasses = 1;
	RenderPass passes[RECURSION_MAX_PASSES];
	passes[0] = RenderPass(1.0, rayOrigin, rayDir, 1.0);
	
	for (int bounce=0; bounce < RECURSION_MAX_PASSES || bounce < queuedPasses; bounce++)
	{
		RenderPass currentPass = passes[bounce];
		RenderPassResult result = calcPass(currentPass, time);
		
		vec3 passColor = calcPassColor(result, time);
		
		// Apply fog (which depends on camera distance) to blending coefficient accumulator
		float fogBlend = 1.0 - pow(clamp((distance(rayOrigin, result.hitPoint) - FOG_DISTANCE + FOG_FADE_DISTANCE)/(FOG_DISTANCE - FOG_FADE_DISTANCE), 0.0, 1.0), FOG_POWER);
		
		// Add pass color to final color
		color += mix(skyColor(currentPass.rayDir), passColor, fogBlend) * currentPass.blendCoeff;
		
		currentPass.blendCoeff *= fogBlend;
		
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
				
				if (currentPass.invert > 0.0) {
					refractionPass.rayDir = refract(currentPass.rayDir, result.normal, 1.0 / result.hitSurface.refractionIndex);
				} else {
					refractionPass.rayDir = refract(currentPass.rayDir, -result.normal, result.hitSurface.refractionIndex);
				}
				
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