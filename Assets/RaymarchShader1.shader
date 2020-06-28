Shader "PeerPlay/RaymarchShader1"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

		//Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 3.0



            #include "UnityCG.cginc"
			#include "DistanceFunctions.cginc"

            sampler2D _MainTex;
			//setup
			uniform sampler2D _CameraDepthTexture;
			uniform float4x4 _CamFrustum,_CamToWorld;
			uniform int _MaxIterations;
			uniform float _Accuracy;
			uniform float _maxDistance;

			
			//Color

			uniform fixed4 _GroundColor;
			uniform fixed4 _SphereColor[8];
			uniform float _ColorIntensity;

			//Light
			uniform float3 _LightCol;
			uniform float _LightIntensity;
			
			//Shadow
			uniform float2 _ShadowDistance;
			uniform float _ShadowIntensity,_ShadowPenumbra;
			//uniform float3 _modInterval;
			
			//Reflection
			uniform int _ReflectionCount;
			uniform float _ReflectionIntensity;
			uniform float _EnReflIntensity;
			uniform samplerCUBE _ReflectionCube;

			//SDF
			uniform float4 _sphere;
			uniform float _sphereSmooth;
			uniform float _degreeRotate;


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 ray:TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
				half index = v.vertex.z;
				v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;         
				
				o.ray = _CamFrustum[(int)index].xyz;
				
				/*int index =0;    //这样写也行
				if (v.vertex.x < 0.5 && v.vertex.y > 0.5)
					index = 0;
				else if (v.vertex.x > 0.5 && v.vertex.y > 0.5)
					index = 1;
				else if(v.vertex.x > 0.5 && v.vertex.y < 0.5)
					index = 2;
				else if(v.vertex.x < 0.5 && v.vertex.y < 0.5)
					index =3;
				
				v.vertex.z = 0;
				o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv; 
				o.ray = _CamFrustum[index].xyz;*/
				o.ray /= abs(o.ray.z);

				o.ray = mul(_CamToWorld,o.ray);

				return o;
            }

			/*float sdSphere(float3 p,float s)
			{
				return length(p)-s;
			}*/

			float3 RotateY(float3 v,float degree)
			{
				float rad = 0.0174532925*degree;
				float cosY = cos(rad);
				float sinY = sin(rad);
				return float3(cosY*v.x - sinY*v.z,v.y,sinY*v.x+cosY*v.z);
			}

			float4 distanceField(float3 p)
			{
				//xyz: color    w :distance
				float4 ground = float4(_GroundColor.rgb,sdPlane(p,float4(0,1,0,0)));
				float4 sphere = float4(_SphereColor[0].rgb,sdSphere(p - _sphere.xyz,_sphere.w));
				for(int i = 1;i<8;i++)
				{
					float4 sphereAdd = float4(_SphereColor[i].rgb,sdSphere(RotateY(p,_degreeRotate*i)- _sphere.xyz,_sphere.w));
					sphere = opUS1(sphere,sphereAdd,_sphereSmooth);
				}

				return opU1(sphere,ground);
				//return opS(Sphere1,Box1);
			}

			
            float3 getNormal(float3 pos)
			{

              //  float3 eps = float3( 0.0005, 0.0, 0.0 );
				const float2 eps = float2(0.001,0.0);
                float3 nor = float3(

                distanceField(pos+eps.xyy).w - distanceField(pos-eps.xyy).w,
                distanceField(pos+eps.yxy).w- distanceField(pos-eps.yxy).w,

                distanceField(pos+eps.yyx).w - distanceField(pos-eps.yyx).w);

                return normalize(nor);

            }
			
			float hardShadow(float3 ro,float3 rd,float mint,float maxt)// ro ：射线起始位置  rd：太阳方向   mint：最近阴影距离  maxt：最远阴影距离
			{															//朝光线方向再来一次光线步进，如果撞到了物体就说明光线被该物体挡住了，自身位于阴影中。
				for(float t = mint;t<maxt;)
				{
					float h = distanceField(ro + rd*t).w;
					if(h<0.001)
					{
						return 0.0;
					}
					t+=h;
				}
				return 1.0;
			}

			float softShadow(float3 ro,float3 rd,float mint,float maxt,float k)
			{
				float result = 1.0;
				float sinSun = rd.y / length(rd);      //光线与地面夹角的sin值
				for(float t = mint;t<maxt;)
				{
					float h = distanceField(ro + rd*t).w;
					if(h<0.001)
					{
						return 0.0;
					}
					result = min(result,(k*h/t)/sinSun);				
					t+=h;
				}
				return result;
			}

			uniform float _AoStepsize,_AoIntensity;
			uniform int _AoIterations;

			float AmbientOcclusion(float3 p ,float3 n)
			{
				float step = _AoStepsize;					//每次前进的步长，这里使用固定步长
				float ao = 0.0;
				float dist;
				for(int i=1;i<=_AoIterations;i++)
				{
					dist = step*i;														 //如果附近没有其他物体 dist<DistanceField 最终结果为负数并截为0 返回值=1 即无环境光遮蔽
																						 //如果附近有物体，那么法线步进就会靠近该物体 从而dist>DistanceField 结果大于0，返回值<1
					ao += max(0.0,(dist - distanceField(p + n*dist).w)/dist);
				}
				return(1.0 - ao*_AoIntensity);
			}

			float3 Shading(float3 p,float3 n,fixed3 c)
			{
				float3 result;
				float3 color = c.rgb * _ColorIntensity;
				float3 _LightDir = normalize(_WorldSpaceLightPos0);
				//平行光
				float3 light = (_LightCol*dot(_LightDir,n)*0.5+0.5)*_LightIntensity;
				//shadows
				float shadow = softShadow(p,_LightDir,_ShadowDistance.x,_ShadowDistance.y,_ShadowPenumbra)*0.5 +0.5;
				shadow = max(0.0,pow(shadow,_ShadowIntensity));

				float ao =AmbientOcclusion(p,n);
				result = color*light*shadow*ao;
				return result;
			}

			bool raymarching(float3 ro,float3 rd,float depth,float maxDistance,int maxIterations,inout float3 p,inout fixed3 dColor)  //ro 射线初始位置，rd射线前进方向，depth在深度图采样得到
			{																									  //maxIterations规定光线最多走几步													
				float t = 0;        //光线走的长度																//inout 类似引用，保存碰撞点的位置、颜色信息 

				bool hit;

				for(int i = 0; i<maxIterations;i++)
				{
					if(t>_maxDistance || t>= depth)  //最大边界 || 有物体遮挡
					{
						hit = false;
						break;
					}

					p =ro +rd*t;              //当前位置， rayOrigin + rayDirection*t
					float4 d = distanceField(p);
					if(d.w <_Accuracy)                  //当走到物体表面时，_Accuracy为阈值，越小越精确，一般0.1 - 0.001之间。
					{
						dColor = d.rgb;
						hit = true;
						break;
					}
					t += d.w;							//没走到表面，加上距离场返回的距离值，走下一步。
				}
				return hit;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture,i.uv).r);
				
				depth *= length(i.ray);
				fixed3 col = tex2D(_MainTex,i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin =_WorldSpaceCameraPos;
				fixed4 result ;
				float3 hitPosition;
				fixed3 dColor;

				bool hit =raymarching(rayOrigin,rayDirection,depth,_maxDistance,_MaxIterations,hitPosition,dColor);
				
				if(hit)
				{	
					float3 nor = getNormal(hitPosition);
					float3 s = Shading(hitPosition,nor,dColor);
					result = fixed4(s,1);
					result += fixed4(texCUBE(_ReflectionCube,nor).rgb * _EnReflIntensity *_ReflectionIntensity,0);

					if(_ReflectionCount > 0)
					{
						rayDirection = normalize(reflect(rayDirection,nor));
						rayOrigin = hitPosition + (rayDirection*0.01);
						hit = raymarching(rayOrigin,rayDirection,_maxDistance,_maxDistance*0.5,_MaxIterations/2,hitPosition,dColor);
						if(hit)
						{//第一次反射结果
							float3 nor = getNormal(hitPosition);
							float3 s = Shading(hitPosition,nor,dColor);
							result += fixed4(s*_ReflectionIntensity,0);
							if(_ReflectionCount>1)
							{//第二次反射结果
								rayDirection = normalize(reflect(rayDirection,nor));
								rayOrigin = hitPosition + (rayDirection*0.01);
								hit = raymarching(rayOrigin,rayDirection,_maxDistance,_maxDistance/4,_MaxIterations/4,hitPosition,dColor);
								if(hit)
								{
									float3 nor = getNormal(hitPosition);
									float3 s = Shading(hitPosition,nor,dColor);
									result += fixed4(s*_ReflectionIntensity*0.5,0);
								}
							}
						}
					}
				}
				else
				{
					result = fixed4(0,0,0,0);
				}

				
				return fixed4(col*(1.0 - result.w)+result.xyz*result.w,0.5);
				
            }
            ENDCG
        }
    }
}


