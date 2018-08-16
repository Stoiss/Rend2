uniform sampler2D u_ShadowMap;

//uniform vec3      u_LightForward;
uniform vec3      u_LightUp;
uniform vec3      u_LightRight;
uniform vec4      u_LightOrigin;
uniform float     u_LightRadius;
uniform vec3      u_ViewOrigin;

uniform vec4      u_Local0;			// shadowMapSize, testshadervalues
uniform vec4      u_Local1;			// realLightOrigin[0], realLightOrigin[1], realLightOrigin[2], usingTessellation
uniform vec4      u_Local2;			// playerOrigin[0], playerOrigin[1], playerOrigin[2], invLightPower

varying vec3      var_Position;
//varying vec3      var_Normal;

out vec4 out_Glow;
out vec4 out_Position;
out vec4 out_Normal;
#ifdef __USE_REAL_NORMALMAPS__
out vec4 out_NormalDetail;
#endif //__USE_REAL_NORMALMAPS__

void main()
{
	vec3 lightToPos = var_Position.xyz - u_LightOrigin.xyz;

	float lightDist = distance(var_Position.xyz, u_Local1.xyz);

	float intensity = 1.0 - clamp(lightDist / u_LightRadius, 0.0, 1.0);
	intensity = clamp(pow(intensity, 5.0), 0.0, 1.0);

	intensity = mix(intensity, 0.0, u_Local2.a);

	vec2 st = vec2(-dot(u_LightRight, lightToPos), dot(u_LightUp, lightToPos));
	st = st * 0.5 + 0.5;

	if (!(st.x >= 0.0 && st.x <= 1.0 && st.y >= 0.0 && st.y <= 1.0))
	{
		intensity = 0.0;
	}

	if (var_Position.z > u_Local2.z + 64.0)
	{// Light dir should always be facing down... Why the fuck is rend2 trying to draw shadows above the light???
		intensity = 0.0;
	}

	if (intensity > 0.0)
	{
#if defined(USE_PCF)
		float pcf = float(texture(u_ShadowMap, st + vec2(-1.0 / u_Local0.r, -1.0 / u_Local0.r)).r != 1.0);
		pcf += float(texture(u_ShadowMap, st + vec2(1.0 / u_Local0.r, -1.0 / u_Local0.r)).r != 1.0);
		pcf += float(texture(u_ShadowMap, st + vec2(-1.0 / u_Local0.r, 1.0 / u_Local0.r)).r != 1.0);
		pcf += float(texture(u_ShadowMap, st + vec2(1.0 / u_Local0.r, 1.0 / u_Local0.r)).r != 1.0);
		pcf /= 4.0;
#else
		float pcf = float(texture(u_ShadowMap, st).r != 1.0);
#endif

		intensity *= pcf;
		//intensity = pcf * (1.0 - length(st));
		intensity = clamp(intensity, 0.0, 0.4);
	}

	out_Color.rgb = vec3(.0, .0, .0);
	out_Color.a = intensity;
	out_Glow = vec4(0.0);
	out_Position = vec4(0.0);
	out_Normal = vec4(0.0);
#ifdef __USE_REAL_NORMALMAPS__
	out_NormalDetail = vec4(0.0);
#endif //__USE_REAL_NORMALMAPS__
}
