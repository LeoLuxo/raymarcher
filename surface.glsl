struct Surface {
	float dist;
	vec3 color;
	float specularCoeff;
	float specularPow;
	float reflectionCoeff;
	float refractionCoeff;
	float refractionIndex;
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
	a.refractionCoeff = mix(a.refractionCoeff, b.refractionCoeff, blend);
	a.refractionIndex = mix(a.refractionIndex, b.refractionIndex, blend);
	return a;
}

Surface blendSMin(Surface a, Surface b, float k)
{
	vec2 blend = smin(a.dist, b.dist, k);
	a = blendSurf(a, b, blend.y);
	a.dist = blend.x;
	return a;
}

Surface blendSMax(Surface a, Surface b, float k)
{
	vec2 blend = smax(a.dist, b.dist, k);
	a = blendSurf(a, b, blend.y);
	a.dist = blend.x;
	return a;
}

Surface blendSDiff(Surface a, Surface b, float k)
{
	vec2 blend = smax(a.dist, -b.dist, k);
	a = blendSurf(a, b, blend.y);
	a.dist = blend.x;
	return a;
}