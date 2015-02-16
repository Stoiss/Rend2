/////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define tex2D(tex, coord) texture2D(tex, coord)
#define tex2Dlod(tex, coord) texture2D(tex, coord)
#define lerp(a, b, t) mix(a, b, t)
#define saturate(a) clamp(a, 0.0, 1.0)
#define mad(a, b, c) (a * b + c)
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define int2 ivec2
#define int3 ivec3
#define int4 ivec4
#define bool2 bvec2
#define bool3 bvec3
#define bool4 bvec4
#define frac fract

/////////////////////////////////////////////////////////////////////////////////////////////////////////////

uniform sampler2D u_TextureMap;
//uniform sampler2D u_LevelsMap;
uniform sampler2D u_ScreenDepthMap;
uniform sampler2D u_NormalMap; // actually saturation map image

varying vec2		var_TexCoords;
varying vec2		var_Dimensions;
varying vec4		var_ViewInfo; // zmin, zmax, zmax / zmin

varying vec4		var_Local0; // CURRENT_PASS_NUMBER, 0, 0, 0

float				CURRENT_PASS_NUMBER = var_Local0.x;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////

vec2 texCoord = var_TexCoords;
vec4 ScreenSize = vec4(var_Dimensions.x, 1.0 / var_Dimensions.x, var_Dimensions.y, 1.0 / var_Dimensions.y);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
*CSSGI shader (Coherent Screen Space Global Illumination)
*This shader requires a depth pass and a normal map pass.
*/


//#define NUM_SAMPLES 8
#define NUM_SAMPLES 6
//#define NUM_SAMPLES 4

//uniform sampler2D u_ScreenDepthMap;// Depth
//uniform sampler2D normal;
//uniform sampler2D u_TextureMap;

float depthMult = 255.0;

vec3 normal_from_depth(float depth, vec2 texcoords) {
  
  vec2 offset1 = vec2(0.0, 1.0 / var_Dimensions.y);
  vec2 offset2 = vec2(1.0 / var_Dimensions.x, 0.0);
  
  float depth1 = texture2D(u_ScreenDepthMap, texcoords + offset1).r * depthMult;
  float depth2 = texture2D(u_ScreenDepthMap, texcoords + offset2).r * depthMult;
  
  vec3 p1 = vec3(offset1, depth1 - depth);
  vec3 p2 = vec3(offset2, depth2 - depth);
  
  vec3 normal = cross(p1, p2);
  normal.z = -normal.z;
  
  return normalize(normal);
}

vec3 SampleNormals(sampler2D normalMap, in vec2 coord)  
{  
	 float depth = texture2D(u_ScreenDepthMap, coord/*var_TexCoords*/).r * depthMult;
	 return normal_from_depth(depth, coord);
}

/*
vec4 SampleNormals(sampler2D normalMap, vec2 t)
{
	vec3 color = texture2D(normalMap, t).rgb;

#define const_1 ( 16.0 / 255.0)
#define const_2 (255.0 / 219.0)
	vec3 color2 = ((color - const_1) * const_2);
#define const_3 ( 125.0 / 255.0)
#define const_4 (255.0 / 115.0)
		
	color = ((color - const_3) * const_4);

	//vec3 orig_color = color * 2.0;
	vec3 orig_color = color + color2;

	orig_color = clamp(orig_color, 0.0, 1.0);
	float combined_color2 = orig_color.r + orig_color.g + orig_color.b;
	combined_color2 /= 4.0;

	return vec4(clamp(1.0 - combined_color2, 0.0, 1.0));
}
*/

#define PI  3.14159265

float width = var_Dimensions.x; //texture width
float height = var_Dimensions.y; //texture height

vec2 texel = vec2(1.0/width,1.0/height);

float rand2(vec2 coord) //generating noise/pattern texture for dithering
{
	float noise = ((fract(1.0-coord.s*(width/2.0))*0.25)+(fract(coord.t*(height/2.0))*0.75))*2.0-1.0;
	return noise;
}

//noise producing function to eliminate banding (got it from someone else�s shader):
float rand(vec2 co){
	return 0.5+(fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453))*0.5;
	//return 1.0;
}

void main()
{    
	//gl_FragColor = texture2D(u_NormalMap, texCoord.st);
	//return;

#if 1
	//calculate sampling rates:
	float ratex = (1.0/var_Dimensions.x);
	float ratey = (1.0/var_Dimensions.y);

	//initialize occlusion sum and gi color:
	float sum = 0.0;
	vec3 fcolor = vec3(0,0,0);

	//far and near clip planes:
	//float zFar = 80.0;
	//float zNear = 0.5;
	//float zNear = ratex;//0.001;//var_ViewInfo.x;//0.5;
	//float zFar = var_ViewInfo.y / var_Dimensions.x;
	//float zFar = var_ViewInfo.y;
	//float zNear = var_ViewInfo.x;
	//float zFar = 80.0;
	float zFar = 1.0;
	float zNear = var_ViewInfo.x / var_Dimensions.x;
	//float zFar = 1.0;
	//float zNear = 0.0005;

	//get depth at current pixel:
	float prof = texture2D(u_ScreenDepthMap, texCoord.st).x;
	//scale sample number with depth:
	float samples = round(NUM_SAMPLES/(0.5+prof));
	prof = zFar * zNear / (prof * (zFar - zNear) - zFar);  //linearize z sample

	//obtain normal and color at current pixel:
	vec3 norm = normalize(vec3(SampleNormals(u_TextureMap,texCoord.st).xyz)*2.0-vec3(1.0));
	vec3 dcolor1 = texture2D(u_TextureMap, texCoord.st).xyz;

	float hf = samples/2;

	//calculate kernel steps:
	float incx = ratex*60;//30;//gi radius
	float incy = ratey*60;//30;

	float incx2 = ratex*8;//ao radius
	float incy2 = ratey*8;

	//do the actual calculations:
	for(float i=-hf; i < hf; i+=1.0){
		for(float j=-hf; j < hf; j+=1.0){

			if (i != 0 || j!= 0) {

				vec2 coords = vec2(i*incx,j*incy)/prof;
				vec2 coords2 = vec2(i*incx2,j*incy2)/prof;

				float prof2 = texture2D(u_ScreenDepthMap,texCoord.st+coords*rand(texCoord)).x;
				prof2 = zFar * zNear / (prof2 * (zFar - zNear) - zFar);  //linearize z sample

				float prof2g = texture2D(u_ScreenDepthMap,texCoord.st+coords2*rand(texCoord)).x;
				prof2g = zFar * zNear / (prof2g * (zFar - zNear) - zFar);  //linearize z sample

				vec3 norm2g = normalize(vec3(SampleNormals(u_TextureMap,texCoord.st+coords2*rand(texCoord)).xyz)*2.0-vec3(1.0)); 

				//vec3 dcolor2 = texture2D(u_TextureMap, texCoord.st+coords*rand(texCoord)).xyz;
				vec3 dcolor3 = texture2D(u_NormalMap, texCoord.st+coords*rand(texCoord)).xyz;
				//dcolor3 = (dcolor3 + dcolor2 + dcolor2) / 3.0;
				//dcolor3 *= 100.0;//10.0;
				//dcolor3 = clamp(dcolor3, 0.0, 1.0);
				//if (length(dcolor3.rgb) < 1.0) dcolor3.rgb *= 100.0;

				//if (length(dcolor3.rgb) <= 0.0) dcolor3+=0.05;
				//while (length(dcolor3.rgb) < 2.0) dcolor3.rgb *= 10.0;

				//dcolor3 *= 5.0;

				//OCCLUSION:

				//calculate approximate pixel distance:
				vec3 dist2 = vec3(coords2,prof-prof2g);

				//calculate normal and sampling direction coherence:
				float coherence2 = dot(normalize(-coords2),normalize(vec2(norm2g.xy)));

				//if there is coherence, calculate occlusion:
				if (coherence2 > 0){
					float pformfactor2 = 0.5*((1.0-dot(norm,norm2g)))/(3.1416*pow(abs(length(dist2*2)),2.0)+0.5);//el 4: depthscale
					sum += clamp(pformfactor2*0.2,0.0,1.0);//ao intensity; 
				}

				//COLOR BLEEDING:

				//if (length(dcolor2)>0.3){//color threshold
				//if (length(dcolor2)>0.0){//color threshold
				//if (length(dcolor2)>length(dcolor1)){//color threshold
				//if (length(dcolor3)>length(dcolor1)){//color threshold
				{
					vec3 norm2 = normalize(vec3(SampleNormals(u_TextureMap,texCoord.st+coords*rand(texCoord)).xyz)*2.0-vec3(1.0)); 

					//calculate approximate pixel distance:
					vec3 dist = vec3(coords,abs(prof-prof2));

					//calculate normal and sampling direction coherence:
					float coherence = dot(normalize(-coords),normalize(vec2(norm2.xy)));

					//if there is coherence, calculate bleeding:
					if (coherence > 0){
						float pformfactor = ((1.0-dot(norm,norm2)))/(3.1416*pow(abs(length(dist*2)),2.0)+0.5);//el 4: depthscale
						//fcolor += dcolor2*(clamp(pformfactor,0.0,1.0));
						fcolor += dcolor3*(clamp(pformfactor,0.0,1.0));
					}
				}

			}
		}
	}

	vec3 bleeding = (fcolor/samples)*0.5;
	float occlusion = 1.0-((sum/samples)*0.7);

	//gl_FragColor = vec4(vec3((dcolor1*occlusion)+(bleeding*0.5)),1.0);
	//gl_FragColor = vec4(vec3((dcolor1*occlusion)+(bleeding*0.1)),1.0);

	// UQ1: Adjust bleed ammount...
	bleeding *= clamp(length(dcolor1)*0.333, 0.0, 1.0);

	// UQ1: Adjust occlusion ammount...
	//occlusion *= (1.0 / length(dcolor1));
	//occlusion = clamp(occlusion, 0.5, 1.0);

	/*if (length(dcolor1) > 0.2)
		occlusion = 1.0;
	else
		occlusion *= clamp(length(dcolor1)*30.0, 0.0, 1.0);*/
	
	vec3 final_color = vec3((dcolor1* occlusion) + (bleeding)) * 1.22;

	// UQ1: Let's add some of the flare color as well... Just to oost colors/glows...
	vec3 flare_color = clamp(texture2D(u_NormalMap, texCoord.st).rgb, 0.0, 1.0);
	final_color = (final_color + clamp(final_color * (flare_color * 3.0), 0.0, 1.0)) / 2.0;

	gl_FragColor = vec4(final_color,1.0);
#else //!0
	vec3 final_color = texture2D(u_TextureMap, texCoord.st).xyz;
	//vec3 flare_color = clamp(texture2D(u_NormalMap, texCoord.st).rgb * 30.0, 0.0, 1.0);
	//final_color = (final_color + (final_color * flare_color) + (final_color * flare_color) + (final_color * flare_color)) / 4.0;

	//vec3 flare_color = clamp(texture2D(u_NormalMap, texCoord.st).rgb * 30.0, 0.0, 1.0);
	//final_color = (final_color + clamp(final_color + ((final_color + flare_color) * final_color), 0.0, 1.0)) / 2.0;

	vec3 flare_color = clamp(texture2D(u_NormalMap, texCoord.st).rgb, 0.0, 1.0);
	//final_color = (final_color + clamp((flare_color * 2.0) * final_color, 0.0, 1.0) + clamp(final_color + (flare_color * 0.5), 0.0, 1.0)) / 3.0;
	final_color = (final_color + clamp(final_color * (flare_color * 3.0), 0.0, 1.0)) / 2.0;

	gl_FragColor = vec4(final_color,1.0);
#endif
}
