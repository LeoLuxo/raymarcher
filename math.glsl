

vec3 reflect(vec3 incident, vec3 normal) {
	return incident - 2.0 * dot(normal, incident) * normal
}

vec3 refract(vec3 incident, vec3 normal, float eta) {
	vec3 r;
	k = 1.0 - eta * eta * (1.0 - dot(normal, incident) * dot(normal, incident));
	if (k < 0.0)
		r = vec3(0.0);
	else
		r = eta * incident - (eta * dot(normal, incident) + sqrt(k)) * normal;
	return r
}