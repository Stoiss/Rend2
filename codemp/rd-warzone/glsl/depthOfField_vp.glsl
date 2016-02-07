in vec3 attr_Position;
in vec4 attr_TexCoord0;

uniform mat4   u_ModelViewProjectionMatrix;

uniform vec2	u_Dimensions;
uniform vec4	u_ViewInfo; // zfar / znear, zfar

uniform vec4	u_Local0; // test, 0, 0, 0

varying vec2   var_TexCoords;
varying vec2   var_Dimensions;
varying vec4   var_ViewInfo; // zfar / znear, zfar
varying vec4   var_Local0; // test, 0, 0, 0

void main()
{
	gl_Position = u_ModelViewProjectionMatrix * vec4(attr_Position, 1.0);
	var_TexCoords = attr_TexCoord0.st;
	var_Dimensions = u_Dimensions.st;
	var_ViewInfo = u_ViewInfo;
	var_Local0 = u_Local0;
}
