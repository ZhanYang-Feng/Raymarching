Shader "PeerPlay/RaymarchShader"
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
			uniform float _maxDistance,_box1round,_boxSphereSmooth,_sphereIntersectSmooth;
			uniform float4 _sphere1,_sphere2,_box1;
			
			//Color
			uniform fixed4 _mainColor;

			//Light
			uniform float3 _LightCol;
			uniform float _LightIntensity;
			
			//Shadow
			uniform float2 _ShadowDistance;
			uniform float _ShadowIntensity,_ShadowPenumbra;
			//uniform float3 _modInterval;
			
			//SDF
		


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

				o.ray /= abs(o.ray.z);

				o.ray = mul(_CamToWorld,o.ray);

				return o;
            }

			/*float sdSphere(float3 p,float s)
			{
				return length(p)-s;
			}*/

			float BoxSphere(float3 p)
			{
				float Sphere1 = sdSphere(p - _sphere1.xyz, _sphere1.w);
				float Box1 = sdRoundBox(p - _box1.xyz,_box1.www,_box1round);
				float combine1 = opSS(Sphere1,Box1,_boxSphereSmooth);
				float Sphere2 = sdSphere(p - _sphere2.xyz, _sphere2.w);
				float combine2 = opIS(Sphere2,combine1,_sphereIntersectSmooth);
				return combine2;
			}

			float distanceField(float3 p)
			{
				
				float ground = sdPlane(p,float4(0,1,0,0));
				float boxSphere1 = BoxSphere(p);
				return opU(ground,boxSphere1);

				//return opS(Sphere1,Box1);
			}

			
            float3 getNormal(float3 pos)
			{

              //  float3 eps = float3( 0.0005, 0.0, 0.0 );
				const float2 eps = float2(0.001,0.0);
                float3 nor = float3(

                distanceField(pos+eps.xyy) - distanceField(pos-eps.xyy),
                distanceField(pos+eps.yxy)- distanceField(pos-eps.yxy),

                distanceField(pos+eps.yyx) - distanceField(pos-eps.yyx));

                return normalize(nor);

            }

			float hardShadow(float3 ro,float3 rd,float mint,float maxt)
			{
				for(float t = mint;t<maxt;)
				{
					float h = distanceField(ro + rd*t);
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
				for(float t = mint;t<maxt;)
				{
					float h = distanceField(ro + rd*t);
					if(h<0.001)
					{
						return 0.0;
					}
					result = min(result,k*h/t);
					t+=h;
				}
				return result;
			}

			uniform float _AoStepsize,_AoIntensity;
			uniform int _AoIterations;

			float AmbientOcclusion(float3 p ,float3 n)
			{
				float step = _AoStepsize;
				float ao = 0.0;
				float dist;
				for(int i=1;i<=_AoIterations;i++)
				{
					dist = step*i;
					ao += max(0.0,(dist - distanceField(p + n*dist))/dist);
				}
				return(1.0 - ao*_AoIntensity);
			}

			float3 Shading(float3 p,float3 n)
			{
				float3 result;
				float3 color = _mainColor.rgb;
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

			fixed4 raymarching(float3 ro,float3 rd,float depth)  //ro 射线初始位置，rd射线前进方向，depth在深度图采样得到
			{
				fixed4 result = fixed4(1,1,1,1);
				const int max_iteration = _MaxIterations;  //规定光线最多走几步
				float t = 0;        //光线走的长度

				for(int i = 0; i<max_iteration;i++)
				{
					if(t>_maxDistance || t>= depth)  //最大边界 || 有物体遮挡
					{
						result = fixed4(rd,0);
						break;
					}

					float3 p =ro +rd*t;              //当前位置， rayOrigin + rayDirection*t
					float d = distanceField(p);
					if(d<_Accuracy)                  //当走到物体表面时，_Accuracy为阈值，越小越精确，一般0.1 - 0.001之间。
					{
						float3 nor = getNormal(p);
						
						float s = Shading(p,nor);

						result = fixed4(_mainColor.rgb*s,1);
						break;
					}
					t += d;							//没走到表面，加上距离场返回的距离值，走下一步。
				}
				return result;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture,i.uv).r);
				//float oriColor = 
				depth *= length(i.ray);
				fixed3 col = tex2D(_MainTex,i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin =_WorldSpaceCameraPos;
				fixed4 result = raymarching(rayOrigin,rayDirection,depth);
				//fixed4 finalColor = fixed4(lerp(col*(1.0 - result.w)+result.xyz*result.w,col,0.5),1.0);
				return fixed4(col*(1.0 - result.w)+result.xyz*result.w,0.5);
				//return finalColor;
            }
            ENDCG
        }
    }
}


/*float modX = pMod1(p.x,_modInterval.x);
				float modY = pMod1(p.y,_modInterval.y);
				float modZ = pMod1(p.z,_modInterval.z);*/